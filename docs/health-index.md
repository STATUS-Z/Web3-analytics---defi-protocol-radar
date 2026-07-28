# Health Index

## Plain language

**Health Index (0–100)** = where today's combined protocol radar strength ranks vs the last ~120 days.

- **0** — weakest day in the window  
- **100** — strongest day in the window  
- Not USD. Not TVL. A **relative rank** of multi-axis polygon strength.

## Math

1. Build 8-axis z-scores (0–1) per protocol per day (same geometry as Crown).
2. Shoelace polygon area per protocol/day.
3. `sector_area(day) = SUM(protocol areas)` for the selected set.
4. `health_index = ROUND(100 * PERCENT_RANK() OVER (ORDER BY sector_area), 0)`.
5. Apply fixed bands:

| Band | Range | Meaning |
|------|-------|---------|
| Weak | 0–24 | Soft vs this window |
| Soft | 25–49 | Below typical |
| Strong | 50–74 | Healthy / above typical |
| Hot | 75–100 | Top-quartile strength |

## Where it appears

| Surface | Query | Display |
|---------|-------|---------|
| Scoreboard counter | 7997414 | `68 · Strong` |
| Story badges | 8034055 | Rising/Softening + band word |
| Story chart | 7997419 | Line/area of `health_index` over time |
| Vault | 7997419 column `sector_area_raw` | Pre-percentile sum for auditors |

## Chart encoding (7997419)

| Column | Role |
|--------|------|
| `fill_weak` / `fill_soft` / `fill_strong` / `fill_hot` | Constant 25 each — stacked area = band regions (left axis) |
| `health_index` | Dual-axis line/area — where the day sits (right axis preferred) |
| `health_band` / `band_insight` | Labels / tooltips |
| `sector_area_raw` | Hide on chart; keep for Vault |

**No hex / color_map columns in SQL.** Set series colors in Dune UI (`docs/color-palette.md`).

## Trend badge (8034055)

```text
IF health_index(snapshot) >= health_index(snapshot - 7d)
  THEN 'Rising'
  ELSE 'Softening'
```

## Product rules

- Do not rename bands without updating banner, glossary, scoreboard, and chart fills together.
- Do not replace Health Index with raw `avg_zscore` in user-facing counters.
- Do not invent alternate formulas in README copy — this file + `7997419` are canonical.
