# SQL CTE pipeline

Shared spine across Crown / Scoreboard / Story / Context / Vault queries. Names vary slightly per file; logic matches.

## 1. Params

```sql
params AS (
  SELECT DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) AS snapshot_date,
         DATE(CAST('{{date_snapshot}}' AS TIMESTAMP)) - INTERVAL '120' DAY AS history_start,
         ...
)
```

- History window ≈ **120 days** ending at `date_snapshot`.
- `protocol_list` parses comma-separated `{{protocols}}`.

## 2. Axis definition

Eight axes (index → polar angle):

| Index | Label | Key |
|------:|-------|-----|
| 0 | Liquidity | liquidity |
| 1 | Efficiency | efficiency |
| 2 | Revenue | revenue |
| 3 | Users | users |
| 4 | Health | health |
| 5 | Stickiness | stickiness |
| 6 | Momentum | momentum |
| 7 | Whale | whale |

## 3. Raw daily metrics (`CTE_1` / `daily`)

| Protocol | Source | Notes |
|----------|--------|-------|
| Uniswap, Curve | `dex.trades` | Fees ≈ 0.3% / 0.04%; TVL heuristic `volume * 3` |
| Aave, Maker | `lending.supply` | Maker mapped via `spark` project filter in pipeline |
| Lido | `lido_ethereum.steth_evt_submitted` | ETH amount × price proxy |

These are **relative** inputs for z-scores, not audited AUM statements.

## 4. Metric derivation

From daily aggregates:

- **liquidity** — `GREATEST(tvl_usd, 1)`
- **efficiency** — `volume / tvl`
- **revenue** — fees
- **users** — distinct actors
- **health** — drawdown-ish vs 7d peak TVL
- **stickiness** — day-over-day user ratio
- **momentum** — 7d volume change
- **whale** — share of day volume, capped

## 5. Long format → z-score (`CTE_2`)

Per `metric_date` × `axis_key`:

1. Compute mean / stddev across protocols.
2. Clamp z to [-3, 3].
3. Rescale to **0–1** score.

## 6. Polar map (`CTE_3`)

```text
x = score * cos(2π * axis_index / 8)
y = score * sin(2π * axis_index / 8)
```

Dune has no native spider chart — Crown uses a **line chart closed-loop hack** (`CTE_7` duplicates axis 0 as index 8).

## 7. Ghost trails (`CTE_4`)

`time_offset` ∈ {7d, 30d, 90d} adds lagged polygons (T-7 / T-30 / T-90) as faded series.

## 8. Shoelace area (`CTE_5`)

```text
area = 0.5 * |Σ (x_i * y_{i+1} - x_{i+1} * y_i)|
```

Per protocol (and optionally period). Larger area ⇒ stronger multi-axis day.

## 9. Sector + Health Index

```text
sector_area(day) = Σ protocol areas
health_index     = ROUND(100 * PERCENT_RANK(sector_area), 0)
```

Bands applied in SELECT / badge queries — see `health-index.md`.

## 10. Widget-specific branches

| Query | Extra logic |
|-------|-------------|
| 7995136 | `{{widget}}` UNION router; sector average polygon; anomaly 30d |
| 7997414 | Scoreboard strings + Market Pulse from cross-protocol vol percentile |
| 7997418 | SPIKE if sector area > 1.15× 7d MA |
| 7997419 | Stacked `fill_*` columns (25 each) for band regions |
| 8034055 | Compare Health Index vs T-7 → Rising / Softening |
| 7997415 | Filter one `decomp_axis`; leaderboard note |
| 7997416 | Column high/low flags for audit table |
| 7995854 | Max recent block + `CURRENT_TIMESTAMP` |

## Files

| File | Query |
|------|-------|
| `sql/7995136-master-pipeline.sql` | Master |
| `sql/7997414-health-scoreboard.sql` | Scoreboard |
| `sql/7997415-axis-breakdown.sql` | Context |
| `sql/7997416-audit-matrix.sql` | Audit |
| `sql/7997418-volatility-sentinel.sql` | Anomaly |
| `sql/7997419-health-index-timeline.sql` | Timeline |
| `sql/8034055-trend-health-band.sql` | Trend badges |
| `sql/7995854-chain-sync-status.sql` | Heartbeat |
