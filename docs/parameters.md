# Parameters

## Live filter row (dashboard 216253)

| Param | Type | Default (live) | Used by |
|-------|------|----------------|---------|
| `date_snapshot` | text (timestamp) | `2026-07-17 00:00:00` | All scored queries |
| `decomp_axis` | enum | `Liquidity` | Context (7997415); also in master |
| `protocols` | text CSV | `Uniswap,Aave,Lido,Maker,Curve` | All scored queries |
| `selected_protocol` | enum | `All` | Crown radar focus |
| `time_offset` | enum `7d`/`30d`/`90d` | `30d` | Ghost trail depth |
| `widget` | enum | `radar` | Legacy master router only |

Enum options for `decomp_axis`: Liquidity · Efficiency · Revenue · Users · Health · Stickiness · Momentum · Whale.

## Re-link after `updateDashboard`

API full-widget saves mint new `widgetId`s. Param controls can point at dead IDs.

**Target wiring:**

| Parameter | Attach to query | Attach to viz widget |
|-----------|-----------------|----------------------|
| date_snapshot | 7995136 | RADAR **2287564** |
| protocols | 7995136 | RADAR **2287564** |
| selected_protocol | 7995136 | RADAR **2287564** |
| time_offset | 7995136 | RADAR **2287564** |
| decomp_axis | **7997415** | ASSET DECOMP **2287574** |

Prefer removing the **`widget`** filter from the UI if Crown always runs as radar.

## Shared params across queries

Dune does not auto-sync one filter to every query. After forking:

1. Create matching parameter names on each query.
2. Or keep a single "driver" query and accept drift on specialized panels.
3. Document defaults in query descriptions.

## Snapshot date tip

Pick a date with full Spellbook coverage. Weekend / laggy days can look artificially Weak.
