/* Protocol Signal Lab — Volatility Sentinel
   Anomaly detector: flags when aggregate radar area deviates from 7-day MA. */
WITH
params AS (
    SELECT DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) AS snapshot_date,
        DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) - INTERVAL '120' DAY AS history_start
),
protocol_list AS (
    SELECT TRIM(p) AS protocol_name FROM unnest(split('{{protocols}}', ',')) AS t(p) WHERE TRIM(p) <> ''
),
axis_def AS (
    SELECT * FROM (VALUES (0,'Liquidity','liquidity'),(1,'Efficiency','efficiency'),(2,'Revenue','revenue'),(3,'Users','users'),
        (4,'Health','health'),(5,'Stickiness','stickiness'),(6,'Momentum','momentum'),(7,'Whale','whale')) AS t(axis_index,annotation_label,axis_key)
),
daily AS (
    SELECT CASE dt.project WHEN 'uniswap' THEN 'Uniswap' ELSE 'Curve' END AS protocol_name,
        CAST(dt.block_time AS DATE) AS metric_date, SUM(dt.amount_usd) AS volume_usd,
        SUM(dt.amount_usd * CASE dt.project WHEN 'uniswap' THEN 0.003 ELSE 0.0004 END) AS fees_usd,
        COUNT(DISTINCT dt.tx_from) AS users, SUM(dt.amount_usd)*3 AS tvl_usd
    FROM dex.trades dt CROSS JOIN params p
    WHERE dt.blockchain='ethereum' AND dt.project IN ('uniswap','curve')
      AND dt.block_month >= DATE_TRUNC('month', p.history_start)
      AND CAST(dt.block_time AS DATE) BETWEEN p.history_start AND p.snapshot_date
      AND EXISTS (SELECT 1 FROM protocol_list pl WHERE pl.protocol_name IN ('Uniswap','Curve'))
    GROUP BY 1,2
    UNION ALL
    SELECT CASE ls.project WHEN 'aave' THEN 'Aave' ELSE 'Maker' END, CAST(ls.block_time AS DATE),
        SUM(ls.amount_usd), SUM(ls.amount_usd)*0.0005, COUNT(DISTINCT ls.depositor), SUM(ls.amount_usd)*10
    FROM lending.supply ls CROSS JOIN params p
    WHERE ls.blockchain='ethereum' AND ls.project IN ('aave','spark')
      AND ls.block_month >= DATE_TRUNC('month', p.history_start)
      AND CAST(ls.block_time AS DATE) BETWEEN p.history_start AND p.snapshot_date
      AND EXISTS (SELECT 1 FROM protocol_list pl WHERE pl.protocol_name IN ('Aave','Maker'))
    GROUP BY 1,2
    UNION ALL
    SELECT 'Lido', CAST(s.evt_block_time AS DATE), SUM(CAST(s.amount AS DOUBLE)/1e18)*3500,
        SUM(CAST(s.amount AS DOUBLE)/1e18)*3500*0.10/365, COUNT(DISTINCT s.evt_tx_from), SUM(CAST(s.amount AS DOUBLE)/1e18)*350000
    FROM lido_ethereum.steth_evt_submitted s CROSS JOIN params p
    WHERE EXISTS (SELECT 1 FROM protocol_list pl WHERE pl.protocol_name='Lido')
      AND CAST(s.evt_block_time AS DATE) BETWEEN p.history_start AND p.snapshot_date
    GROUP BY 1,2
),
metrics AS (
    SELECT protocol_name, metric_date, GREATEST(tvl_usd,1) AS liquidity, volume_usd/GREATEST(tvl_usd,1) AS efficiency,
        fees_usd AS revenue, CAST(users AS DOUBLE) AS users,
        GREATEST(0,1-tvl_usd/GREATEST(MAX(tvl_usd) OVER (PARTITION BY protocol_name ORDER BY metric_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),1)) AS health,
        COALESCE(users*1.0/NULLIF(LAG(users,1) OVER (PARTITION BY protocol_name ORDER BY metric_date),0),0) AS stickiness,
        COALESCE((volume_usd-LAG(volume_usd,7) OVER (PARTITION BY protocol_name ORDER BY metric_date))/NULLIF(LAG(volume_usd,7) OVER (PARTITION BY protocol_name ORDER BY metric_date),0),0) AS momentum,
        LEAST(0.8,volume_usd/NULLIF(SUM(volume_usd) OVER (PARTITION BY metric_date),0)) AS whale
    FROM daily
),
long_fmt AS (
    SELECT protocol_name, metric_date, 'liquidity' AS axis_key, liquidity AS raw_value FROM metrics
    UNION ALL SELECT protocol_name, metric_date, 'efficiency', efficiency FROM metrics
    UNION ALL SELECT protocol_name, metric_date, 'revenue', revenue FROM metrics
    UNION ALL SELECT protocol_name, metric_date, 'users', users FROM metrics
    UNION ALL SELECT protocol_name, metric_date, 'health', health FROM metrics
    UNION ALL SELECT protocol_name, metric_date, 'stickiness', stickiness FROM metrics
    UNION ALL SELECT protocol_name, metric_date, 'momentum', momentum FROM metrics
    UNION ALL SELECT protocol_name, metric_date, 'whale', whale FROM metrics
),
zscore AS (
    SELECT l.protocol_name, l.metric_date, a.axis_index, l.raw_value,
        GREATEST(0,LEAST(1,(GREATEST(-3,LEAST(3,COALESCE((l.raw_value-AVG(l.raw_value) OVER (PARTITION BY l.metric_date,l.axis_key))
            /NULLIF(STDDEV(l.raw_value) OVER (PARTITION BY l.metric_date,l.axis_key),0),0)))+3)/6)) AS score
    FROM long_fmt l INNER JOIN axis_def a ON l.axis_key=a.axis_key
),
polar AS (
    SELECT z.*, z.score*COS((2*PI()/8)*z.axis_index) AS x_coord, z.score*SIN((2*PI()/8)*z.axis_index) AS y_coord, z.axis_index AS sort_order
    FROM zscore z
),
pb_pairs AS (
    SELECT protocol_name, metric_date, x_coord, y_coord,
        LEAD(y_coord) OVER (PARTITION BY protocol_name, metric_date ORDER BY sort_order) AS y_next,
        LEAD(x_coord) OVER (PARTITION BY protocol_name, metric_date ORDER BY sort_order) AS x_next
    FROM polar
),
playback AS (
    SELECT metric_date, SUM(area_score) AS total_area_score,
        AVG(SUM(area_score)) OVER (ORDER BY metric_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7d
    FROM (SELECT protocol_name, metric_date, 0.5*ABS(SUM(x_coord*y_next-x_next*y_coord)) AS area_score FROM pb_pairs WHERE x_next IS NOT NULL GROUP BY 1,2) x
    GROUP BY 1
),
anomaly AS (
    SELECT CASE WHEN total_area_score>ma_7d*1.15 THEN 1 ELSE 0 END AS anomaly_flag,
        ABS((total_area_score-ma_7d)/NULLIF(ma_7d,0))*100 AS deviation_pct
    FROM playback pb CROSS JOIN params p WHERE pb.metric_date=p.snapshot_date
)
SELECT
    CASE WHEN a.anomaly_flag=1 THEN 'SPIKE' ELSE 'STEADY' END AS kpi_value,
    CONCAT('ANOMALY ±', CAST(CAST(ROUND(a.deviation_pct,1) AS DECIMAL(10,1)) AS VARCHAR), '% vs 7d MA') AS annotation_label,
    a.anomaly_flag
FROM anomaly a
