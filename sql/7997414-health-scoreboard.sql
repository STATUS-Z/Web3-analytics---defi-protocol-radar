/*
================================================================================
 Protocol Signal Lab — Health Scoreboard (Scoreboard zone)
================================================================================
 Plain-language headlines — no cryptic 0.5 / UP / HOT codes without words.

 Health Index (same math as Story timeline):
   sector_area = sum of radar shoelace areas across selected protocols (snapshot day)
   health_index = 100 * PERCENT_RANK of that day vs ~120d history
   Bands: Weak 0–24 | Soft 25–49 | Strong 50–74 | Hot 75–100

 Scoreboard row 2 shows e.g. "68 · Strong" so beginners grasp meaning instantly.
================================================================================
*/
WITH
params AS (
    SELECT DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) AS snapshot_date,
        DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) - INTERVAL '120' DAY AS history_start,
        '{{time_offset}}' AS time_offset
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
    SELECT l.protocol_name, l.metric_date, a.axis_index, a.annotation_label, a.axis_key, l.raw_value,
        GREATEST(0,LEAST(1,(GREATEST(-3,LEAST(3,COALESCE((l.raw_value-AVG(l.raw_value) OVER (PARTITION BY l.metric_date,l.axis_key))
            /NULLIF(STDDEV(l.raw_value) OVER (PARTITION BY l.metric_date,l.axis_key),0),0)))+3)/6)) AS score
    FROM long_fmt l INNER JOIN axis_def a ON l.axis_key=a.axis_key
),
polar AS (
    SELECT z.*, z.score*COS((2*PI()/8)*z.axis_index) AS x_coord, z.score*SIN((2*PI()/8)*z.axis_index) AS y_coord,
        z.axis_index AS sort_order
    FROM zscore z
),
period_def AS (
    SELECT 'T0' AS period_label, 0 AS day_offset
    UNION ALL SELECT 'T-7',7 WHERE (SELECT time_offset FROM params) IN ('7d','30d','90d')
),
ghost AS (
    SELECT p.protocol_name, p.score, p.x_coord, p.y_coord, p.sort_order, pd.period_label, pd.trail_date AS metric_date
    FROM polar p INNER JOIN (
        SELECT period_label, prm.snapshot_date - day_offset * INTERVAL '1' DAY AS trail_date FROM period_def CROSS JOIN params prm
    ) pd ON p.metric_date = pd.trail_date
),
shoelace AS (
    SELECT protocol_name, period_label, metric_date, x_coord, y_coord,
        LEAD(y_coord) OVER (PARTITION BY protocol_name, period_label ORDER BY sort_order) AS y_next,
        LEAD(x_coord) OVER (PARTITION BY protocol_name, period_label ORDER BY sort_order) AS x_next, score
    FROM ghost
),
area AS (
    SELECT protocol_name, period_label, metric_date, 0.5*ABS(SUM(x_coord*y_next-x_next*y_coord)) AS area_score, AVG(score) AS avg_zscore
    FROM shoelace WHERE x_next IS NOT NULL GROUP BY 1,2,3
),
-- Full history of sector area for Health Index percentile (T0 days only)
pb_pairs_hist AS (
    SELECT protocol_name, metric_date, x_coord, y_coord,
        LEAD(y_coord) OVER (PARTITION BY protocol_name, metric_date ORDER BY sort_order) AS y_next,
        LEAD(x_coord) OVER (PARTITION BY protocol_name, metric_date ORDER BY sort_order) AS x_next
    FROM polar
),
sector_daily AS (
    SELECT metric_date AS date,
        SUM(area_score) AS sector_area
    FROM (
        SELECT protocol_name, metric_date,
            0.5*ABS(SUM(x_coord*y_next - x_next*y_coord)) AS area_score
        FROM pb_pairs_hist WHERE x_next IS NOT NULL
        GROUP BY 1, 2
    ) x
    GROUP BY 1
),
indexed AS (
    SELECT date, sector_area,
        CAST(ROUND(100.0 * PERCENT_RANK() OVER (ORDER BY sector_area), 0) AS INTEGER) AS health_index
    FROM sector_daily
),
snap_health AS (
    SELECT i.health_index,
        CASE
            WHEN i.health_index < 25 THEN 'Weak'
            WHEN i.health_index < 50 THEN 'Soft'
            WHEN i.health_index < 75 THEN 'Strong'
            ELSE 'Hot'
        END AS health_band
    FROM indexed i CROSS JOIN params p
    WHERE i.date = p.snapshot_date
),
kpi AS (
    SELECT (SELECT protocol_name FROM area a CROSS JOIN params p WHERE period_label='T0' AND metric_date=p.snapshot_date ORDER BY area_score DESC LIMIT 1) AS lead_proto,
        (SELECT CASE WHEN t0.area_score>COALESCE(t7.area_score,0) THEN 'Rising' ELSE 'Softening' END FROM area t0
         LEFT JOIN area t7 ON t0.protocol_name=t7.protocol_name AND t7.period_label='T-7' CROSS JOIN params p
         WHERE t0.period_label='T0' AND t0.metric_date=p.snapshot_date ORDER BY t0.area_score DESC LIMIT 1) AS momentum
),
daily_cross_vol AS (
    SELECT metric_date, STDDEV(area_score) AS cross_protocol_vol
    FROM area WHERE period_label='T0' GROUP BY metric_date
),
vol_context AS (
    SELECT ROUND(100.0 * SUM(CASE WHEN d.cross_protocol_vol > c.cross_protocol_vol THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 0) AS pct_days_calmmer
    FROM daily_cross_vol d
    CROSS JOIN (SELECT cross_protocol_vol FROM daily_cross_vol dc CROSS JOIN params p WHERE dc.metric_date=p.snapshot_date) c
)
SELECT 1 AS sort_order,
    k.lead_proto AS kpi_value,
    'WHO LEADS' AS annotation_label FROM kpi k
UNION ALL SELECT 2,
    COALESCE(CAST(sh.health_index AS VARCHAR) || ' · ' || sh.health_band, 'n/a'),
    'HEALTH INDEX' FROM snap_health sh
UNION ALL SELECT 3,
    k.momentum,
    'MOMENTUM' FROM kpi k
UNION ALL SELECT 4,
    CASE WHEN vc.pct_days_calmmer >= 80 THEN 'Calm'
         WHEN vc.pct_days_calmmer >= 50 THEN 'Mixed'
         ELSE 'Stressed' END,
    'MARKET PULSE' FROM kpi k CROSS JOIN vol_context vc
ORDER BY sort_order
