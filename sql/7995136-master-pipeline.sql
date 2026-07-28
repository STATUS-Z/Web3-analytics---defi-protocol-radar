/* =============================================================================
   PROTOCOL SIGNAL LAB v2.0 — Master Pipeline
   Single parameterized query feeding all dashboard widgets via {{widget}} router.
   Whale-terminal DeFi protocol intelligence: 8-axis radar, ghost trails, KPIs.
   ============================================================================= */
WITH
params AS (
    -- Snapshot date and lookback window; time_offset drives ghost trail depth
    SELECT DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) AS snapshot_date,
        DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) - INTERVAL '120' DAY AS history_start,
        '{{time_offset}}' AS time_offset,
        '{{selected_protocol}}' AS selected_protocol,
        '{{decomp_axis}}' AS decomp_axis,
        '{{widget}}' AS widget
),
protocol_list AS (
    -- Parse comma-separated multiselect into filterable protocol rows
    SELECT TRIM(p) AS protocol_name
    FROM unnest(split('{{protocols}}', ',')) AS t(p)
    WHERE TRIM(p) <> ''
),
axis_def AS (
    -- 8 radar axes: index drives polar angle and sort order for line-chart hack
    SELECT * FROM (VALUES
        (0,'TVL','liquidity'),(1,'Efficiency','efficiency'),(2,'Revenue','revenue'),
        (3,'Users','users'),(4,'Health','health'),(5,'Stickiness','stickiness'),
        (6,'Momentum','momentum'),(7,'Whale Share','whale')
    ) AS t(axis_index, annotation_label, axis_key)
),
period_def AS (
    -- CTE_4 driver: ghost trails scale with time_offset (7d→T0+T-7, 30d→+T-30, 90d→+T-90)
    SELECT 'T0' AS period_label, 0 AS day_offset
    UNION ALL SELECT 'T-7', 7
        WHERE (SELECT time_offset FROM params) IN ('7d','30d','90d')
    UNION ALL SELECT 'T-30', 30
        WHERE (SELECT time_offset FROM params) IN ('30d','90d')
    UNION ALL SELECT 'T-90', 90
        WHERE (SELECT time_offset FROM params) = '90d'
),

/* CTE_1_Raw: daily protocol metrics aggregated to USD (Spellbook curated tables) */
CTE_1_Raw AS (
    SELECT CASE dt.project WHEN 'uniswap' THEN 'Uniswap' ELSE 'Curve' END AS protocol_name,
        CAST(dt.block_time AS DATE) AS metric_date,
        SUM(dt.amount_usd) AS volume_usd,
        SUM(dt.amount_usd * CASE dt.project WHEN 'uniswap' THEN 0.003 ELSE 0.0004 END) AS fees_usd,
        COUNT(DISTINCT dt.tx_from) AS users,
        SUM(dt.amount_usd) * 3 AS tvl_usd
    FROM dex.trades dt CROSS JOIN params p
    WHERE dt.blockchain = 'ethereum' AND dt.project IN ('uniswap','curve')
      AND dt.block_month >= DATE_TRUNC('month', p.history_start)
      AND CAST(dt.block_time AS DATE) BETWEEN p.history_start AND p.snapshot_date
      AND EXISTS (SELECT 1 FROM protocol_list pl WHERE pl.protocol_name IN ('Uniswap','Curve'))
    GROUP BY 1, 2
    UNION ALL
    SELECT CASE ls.project WHEN 'aave' THEN 'Aave' ELSE 'Maker' END,
        CAST(ls.block_time AS DATE),
        SUM(ls.amount_usd), SUM(ls.amount_usd) * 0.0005,
        COUNT(DISTINCT ls.depositor), SUM(ls.amount_usd) * 10
    FROM lending.supply ls CROSS JOIN params p
    WHERE ls.blockchain = 'ethereum' AND ls.project IN ('aave','spark')
      AND ls.block_month >= DATE_TRUNC('month', p.history_start)
      AND CAST(ls.block_time AS DATE) BETWEEN p.history_start AND p.snapshot_date
      AND EXISTS (SELECT 1 FROM protocol_list pl WHERE pl.protocol_name IN ('Aave','Maker'))
    GROUP BY 1, 2
    UNION ALL
    SELECT 'Lido', CAST(s.evt_block_time AS DATE),
        SUM(CAST(s.amount AS DOUBLE) / 1e18) * 3500,
        SUM(CAST(s.amount AS DOUBLE) / 1e18) * 3500 * 0.10 / 365,
        COUNT(DISTINCT s.evt_tx_from),
        SUM(CAST(s.amount AS DOUBLE) / 1e18) * 3500 * 100000
    FROM lido_ethereum.steth_evt_submitted s
    CROSS JOIN params p
    WHERE EXISTS (SELECT 1 FROM protocol_list pl WHERE pl.protocol_name = 'Lido')
      AND CAST(s.evt_block_time AS DATE) BETWEEN p.history_start AND p.snapshot_date
    GROUP BY 1, 2
),
metrics AS (
    -- Derive 8 axis raw values from daily aggregates
    SELECT protocol_name, metric_date,
        GREATEST(tvl_usd, 1) AS liquidity,
        volume_usd / GREATEST(tvl_usd, 1) AS efficiency,
        fees_usd AS revenue,
        CAST(users AS DOUBLE) AS users,
        GREATEST(0, 1 - tvl_usd / GREATEST(
            MAX(tvl_usd) OVER (PARTITION BY protocol_name ORDER BY metric_date
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1)) AS health,
        COALESCE(users * 1.0 / NULLIF(LAG(users, 1) OVER (
            PARTITION BY protocol_name ORDER BY metric_date), 0), 0) AS stickiness,
        COALESCE((volume_usd - LAG(volume_usd, 7) OVER (
            PARTITION BY protocol_name ORDER BY metric_date))
            / NULLIF(LAG(volume_usd, 7) OVER (
            PARTITION BY protocol_name ORDER BY metric_date), 0), 0) AS momentum,
        LEAST(0.8, volume_usd / NULLIF(SUM(volume_usd) OVER (PARTITION BY metric_date), 0)) AS whale
    FROM CTE_1_Raw
),

/* CTE_2_ZScore: cross-protocol z-score per axis-day, clamped and rescaled 0-1 */
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
CTE_2_ZScore AS (
    SELECT l.protocol_name, l.metric_date, a.axis_index, a.annotation_label, a.axis_key, l.raw_value,
        GREATEST(0, LEAST(1, (
            GREATEST(-3, LEAST(3, COALESCE(
                (l.raw_value - AVG(l.raw_value) OVER (PARTITION BY l.metric_date, l.axis_key))
                / NULLIF(STDDEV(l.raw_value) OVER (PARTITION BY l.metric_date, l.axis_key), 0), 0
            ))) + 3) / 6)) AS score
    FROM long_fmt l
    INNER JOIN axis_def a ON l.axis_key = a.axis_key
),

/* CTE_3_Polar_Current: map 0-1 scores to XY for Dune line chart spider hack */
CTE_3_Polar_Current AS (
    SELECT z.*,
        z.score * COS((2 * PI() / 8) * z.axis_index) AS x_coord,
        z.score * SIN((2 * PI() / 8) * z.axis_index) AS y_coord,
        1.15 * COS((2 * PI() / 8) * z.axis_index) AS label_x,
        1.15 * SIN((2 * PI() / 8) * z.axis_index) AS label_y,
        z.axis_index AS sort_order
    FROM CTE_2_ZScore z
),

/* CTE_4_Ghost_Trails: lag snapshot by period_def offsets for time-travel overlays */
CTE_4_Ghost_Trails AS (
    SELECT p.protocol_name, pd.period_label, p.axis_index, p.annotation_label, p.axis_key,
        p.raw_value, p.score, p.x_coord, p.y_coord, p.label_x, p.label_y, p.sort_order,
        pd.trail_date AS metric_date
    FROM CTE_3_Polar_Current p
    INNER JOIN (
        SELECT period_label, prm.snapshot_date - day_offset * INTERVAL '1' DAY AS trail_date
        FROM period_def CROSS JOIN params prm
    ) pd ON p.metric_date = pd.trail_date
),

/* CTE_5_Area_Score: shoelace polygon area per protocol-period-date for playback/KPI */
shoelace_pairs AS (
    SELECT protocol_name, period_label, metric_date, axis_index, x_coord, y_coord, score,
        LEAD(y_coord) OVER (PARTITION BY protocol_name, period_label ORDER BY axis_index) AS y_next,
        LEAD(x_coord) OVER (PARTITION BY protocol_name, period_label ORDER BY axis_index) AS x_next
    FROM CTE_4_Ghost_Trails
),
CTE_5_Area_Score AS (
    SELECT protocol_name, period_label, metric_date,
        0.5 * ABS(SUM(x_coord * y_next - x_next * y_coord)) AS area_score,
        AVG(score) AS avg_zscore
    FROM shoelace_pairs
    WHERE x_next IS NOT NULL
    GROUP BY 1, 2, 3
),
pb_pairs AS (
    SELECT protocol_name, metric_date, axis_index, x_coord, y_coord,
        LEAD(y_coord) OVER (PARTITION BY protocol_name, metric_date ORDER BY axis_index) AS y_next,
        LEAD(x_coord) OVER (PARTITION BY protocol_name, metric_date ORDER BY axis_index) AS x_next
    FROM CTE_3_Polar_Current
),
daily_area AS (
    SELECT protocol_name, metric_date,
        0.5 * ABS(SUM(x_coord * y_next - x_next * y_coord)) AS area_score
    FROM pb_pairs WHERE x_next IS NOT NULL
    GROUP BY 1, 2
),
global_area AS (
    SELECT metric_date, SUM(area_score) AS total_area_score
    FROM daily_area GROUP BY 1
),

/* CTE_6_Anomaly: 30-day rolling mean/std on global area for sentinel card */
CTE_6_Anomaly AS (
    SELECT metric_date, total_area_score,
        AVG(total_area_score) OVER (ORDER BY metric_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS ma_30d,
        STDDEV(total_area_score) OVER (ORDER BY metric_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS std_30d
    FROM global_area
),
anomaly_flag AS (
    SELECT CASE WHEN total_area_score > ma_30d + 1.5 * COALESCE(std_30d, 0) THEN 1 ELSE 0 END AS anomaly_flag,
        ABS((total_area_score - ma_30d) / NULLIF(ma_30d, 0)) * 100 AS deviation_pct,
        metric_date
    FROM CTE_6_Anomaly
),

/* CTE_7_Closing_Loop: append axis_index=0 to close polygon for line chart */
radar_base AS (
    SELECT g.protocol_name, g.period_label, g.axis_index, g.annotation_label, g.sort_order,
        g.score, g.x_coord, g.y_coord, g.label_x, g.label_y, g.metric_date,
        a.area_score,
        CONCAT(g.protocol_name, '_', g.period_label) AS series_name
    FROM CTE_4_Ghost_Trails g
    LEFT JOIN CTE_5_Area_Score a ON g.protocol_name = a.protocol_name
        AND g.period_label = a.period_label AND g.metric_date = a.metric_date
),
-- Sector-average benchmark polygon (T0): compare any protocol vs. the pack
sector_benchmark AS (
    SELECT 'SECTOR AVERAGE' AS protocol_name, g.period_label, g.axis_index, g.annotation_label, g.sort_order,
        AVG(g.score) AS score,
        AVG(g.score) * COS((2 * PI() / 8) * g.axis_index) AS x_coord,
        AVG(g.score) * SIN((2 * PI() / 8) * g.axis_index) AS y_coord,
        1.15 * COS((2 * PI() / 8) * g.axis_index) AS label_x,
        1.15 * SIN((2 * PI() / 8) * g.axis_index) AS label_y,
        g.metric_date,
        CAST(NULL AS DOUBLE) AS area_score,
        CONCAT('SECTOR_AVG_', g.period_label) AS series_name
    FROM CTE_4_Ghost_Trails g
    WHERE g.period_label = 'T0'
    GROUP BY g.period_label, g.axis_index, g.annotation_label, g.sort_order, g.metric_date
),
radar_combined AS (
    SELECT * FROM radar_base
    UNION ALL
    SELECT * FROM sector_benchmark
),
CTE_7_Closing_Loop AS (
    SELECT * FROM radar_combined
    UNION ALL
    SELECT protocol_name, period_label, 8, annotation_label, 8, score,
        x_coord, y_coord, label_x, label_y, metric_date, area_score, series_name
    FROM radar_combined WHERE axis_index = 0
),

/* CTE_8_Decomp: axis breakdown for decomp bar chart filtered by decomp_axis param */
CTE_8_Decomp AS (
    SELECT z.protocol_name, z.annotation_label, z.score
    FROM CTE_2_ZScore z
    CROSS JOIN params p
    WHERE z.metric_date = p.snapshot_date AND z.axis_key = LOWER(p.decomp_axis)
),

kpi AS (
    SELECT
        (SELECT protocol_name FROM CTE_5_Area_Score a CROSS JOIN params p
         WHERE period_label = 'T0' AND metric_date = p.snapshot_date
         ORDER BY area_score DESC LIMIT 1) AS lead_proto,
        (SELECT ROUND(AVG(avg_zscore), 2) FROM CTE_5_Area_Score a CROSS JOIN params p
         WHERE period_label = 'T0' AND metric_date = p.snapshot_date) AS health_avg,
        (SELECT CASE WHEN t0.area_score > COALESCE(t7.area_score, 0) THEN 'UP' ELSE 'DOWN' END
         FROM CTE_5_Area_Score t0
         LEFT JOIN CTE_5_Area_Score t7 ON t0.protocol_name = t7.protocol_name AND t7.period_label = 'T-7'
         CROSS JOIN params p
         WHERE t0.period_label = 'T0' AND t0.metric_date = p.snapshot_date
         ORDER BY t0.area_score DESC LIMIT 1) AS momentum,
        (SELECT ROUND(COALESCE(STDDEV(area_score), 0), 2) FROM CTE_5_Area_Score a CROSS JOIN params p
         WHERE period_label = 'T0' AND metric_date = p.snapshot_date) AS volatility
),
playback AS (
    SELECT ga.metric_date AS date, ga.total_area_score AS playback_area,
        AVG(ga.total_area_score) OVER (ORDER BY ga.metric_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS playback_ma7
    FROM global_area ga
)

-- Widget router: each UNION branch serves one dashboard panel
SELECT r.protocol_name, r.period_label, r.axis_index, r.sort_order, r.x_coord, r.y_coord,
    r.score, r.area_score, CAST(NULL AS BIGINT) AS anomaly_flag,
    r.metric_date AS date, r.annotation_label, r.label_x, r.label_y, r.series_name,
    CAST(NULL AS VARCHAR) AS kpi_value, CAST(NULL AS VARCHAR) AS decomp_protocol,
    CAST(NULL AS DOUBLE) AS decomp_value, CAST(NULL AS DOUBLE) AS playback_area,
    CAST(NULL AS DOUBLE) AS playback_ma7, 'radar' AS widget
FROM CTE_7_Closing_Loop r CROSS JOIN params p
WHERE p.widget = 'radar'
  AND (p.selected_protocol = 'All' OR r.protocol_name = p.selected_protocol OR r.protocol_name = 'SECTOR AVERAGE')

UNION ALL
SELECT NULL, NULL, 1, 1, NULL, NULL, NULL, NULL, NULL, p.snapshot_date,
    'MARKET LEAD', NULL, NULL, NULL, k.lead_proto, NULL, NULL, NULL, NULL, 'kpi'
FROM kpi k CROSS JOIN params p WHERE p.widget = 'kpi'
UNION ALL
SELECT NULL, NULL, 2, 2, NULL, NULL, k.health_avg, NULL, NULL, p.snapshot_date,
    'COMPOSITE HEALTH', NULL, NULL, NULL, CAST(k.health_avg AS VARCHAR), NULL, NULL, NULL, NULL, 'kpi'
FROM kpi k CROSS JOIN params p WHERE p.widget = 'kpi'
UNION ALL
SELECT NULL, NULL, 3, 3, NULL, NULL, NULL, NULL, NULL, p.snapshot_date,
    'MOMENTUM', NULL, NULL, NULL, k.momentum, NULL, NULL, NULL, NULL, 'kpi'
FROM kpi k CROSS JOIN params p WHERE p.widget = 'kpi'
UNION ALL
SELECT NULL, NULL, 4, 4, NULL, NULL, NULL, NULL, NULL, p.snapshot_date,
    'VOLATILITY PULSE', NULL, NULL, NULL, CAST(k.volatility AS VARCHAR), NULL, NULL, NULL, NULL, 'kpi'
FROM kpi k CROSS JOIN params p WHERE p.widget = 'kpi'

UNION ALL
SELECT d.protocol_name, NULL, NULL, NULL, NULL, NULL, d.score, NULL, NULL,
    p.snapshot_date, d.annotation_label, NULL, NULL, NULL, NULL, d.protocol_name, d.score,
    NULL, NULL, 'decomp'
FROM CTE_8_Decomp d CROSS JOIN params p WHERE p.widget = 'decomp'

UNION ALL
SELECT z.protocol_name, NULL, z.axis_index, z.axis_index, NULL, NULL, ROUND(z.score, 2),
    NULL, NULL, z.metric_date, z.annotation_label, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, 'audit'
FROM CTE_2_ZScore z
CROSS JOIN params p
WHERE p.widget = 'audit' AND z.metric_date = p.snapshot_date

UNION ALL
SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, a.anomaly_flag,
    p.snapshot_date,
    CASE WHEN a.anomaly_flag = 1 THEN 'VOLATILITY SPIKE' ELSE 'STEADY STATE' END,
    NULL, NULL, NULL,
    CONCAT('Deviation: ±', CAST(ROUND(a.deviation_pct, 1) AS VARCHAR), '%'),
    NULL, NULL, NULL, NULL, 'anomaly'
FROM anomaly_flag a CROSS JOIN params p
WHERE p.widget = 'anomaly' AND a.metric_date = p.snapshot_date

UNION ALL
SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, pb.date,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, pb.playback_area, pb.playback_ma7, 'playback'
FROM playback pb CROSS JOIN params p WHERE p.widget = 'playback'

UNION ALL
SELECT NULL, NULL, z.axis_index, z.sort_order, z.label_x, z.label_y, z.score, NULL, NULL,
    z.metric_date, z.annotation_label, z.label_x, z.label_y, z.annotation_label,
    NULL, NULL, NULL, NULL, NULL, 'labels'
FROM CTE_3_Polar_Current z CROSS JOIN params p
WHERE p.widget = 'labels' AND z.metric_date = p.snapshot_date
  AND (p.selected_protocol = 'All' OR z.protocol_name = p.selected_protocol)
  AND z.protocol_name = (SELECT MIN(protocol_name) FROM protocol_list)

ORDER BY widget, protocol_name, period_label, sort_order
