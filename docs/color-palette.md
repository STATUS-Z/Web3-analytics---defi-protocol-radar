# Color palette (UI-only)

**Rule:** No hex / `color_map` columns in SQL. Colors are set in the Dune visualization UI.

Source scrape (reference only): Web3 Career CSS inventory under `assets/palette/`.

## Health Index chart series

| Series | Hex | Role |
|--------|-----|------|
| Weak 0–24 | `#DC3545` | Stacked band fill |
| Soft 25–49 | `#FD7E14` | Stacked band fill |
| Strong 50–74 | `#0DCAF0` | Stacked band fill |
| Hot 75–100 | `#19FF85` | Stacked band fill |
| Health Index | `#FFFFFF` | Right-axis series |

## Suggested protocol series (Crown)

| Protocol | Hex | Source role |
|----------|-----|-------------|
| Uniswap | `#0DCAF0` | info/cyan |
| Aave | `#FFC107` | warning/yellow |
| Lido | `#6610F2` | indigo |
| Maker | `#00CD70` | success |
| Curve | `#E6007A` | primary pink |
| SECTOR AVERAGE | `#9C9A9B` | muted gray |

Ghost trails: same hue, lower opacity in the chart UI if available.

## Context / decomp

Accent bar: `#FD7E14`.

## Files

- `assets/palette/palette_map.json` — ranked homepage + PSL role map
- `assets/palette/ALL_HEXES.txt` — full scraped inventory

## Why not SQL colors

Dune MCP cannot set series hex. Encoding colors in query results couples data to one theme and breaks forks. Keep data numeric; paint in the UI.
