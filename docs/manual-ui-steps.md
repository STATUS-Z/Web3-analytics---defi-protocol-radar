# Protocol Signal Lab — Manual UI steps (after copy ship)

Dashboard: https://dune.com/za_chain/protocol-signal-lab-defi-health-dashboard

## 1. Re-link parameter widgets (REQUIRED)

`updateDashboard` regenerates widget IDs every save. Param controls still point at prior-generation IDs.

In Edit dashboard → each filter → Attach to visualization:

| Parameter | Attach to query | Attach to widget (live ID) |
|-----------|-----------------|----------------------------|
| date_snapshot | 7995136 (radar master) | RADAR **2287564** |
| protocols | 7995136 | RADAR **2287564** |
| selected_protocol | 7995136 | RADAR **2287564** |
| time_offset | 7995136 | RADAR **2287564** |
| decomp_axis | **7997415** (decomp, not master) | ASSET DECOMP **2287574** |

Confirm the leftover **widget** master-router param is gone (removed this ship).

## 2. Series colors on HEALTH INDEX chart (11982552 → widget 2287573)

MCP cannot set series hex. Open viz → Series colors:

| Series | Recommended hex |
|--------|-----------------|
| Weak 0–24 (stacked fill) | `#DC3545` |
| Soft 25–49 | `#FD7E14` |
| Strong 50–74 | `#0DCAF0` |
| Hot 75–100 | `#19FF85` |
| Health Index (right axis) | `#FFFFFF` |

Decomp accent (ASSET DECOMP): `#FD7E14`.

## 3. Copy shipped (verify on page)

- Top banner (widget **2287559**, rows 1–5) explains Crown → Scoreboard → Story → Context → Vault + Health Index bands.
- Zone text widgets refreshed (Crown / Story / Glossary / Vault).
- All eight query **descriptions** updated on Dune (see `psl-copy.md`).

## 4. Sanity check

1. Banner readable above the radar.
2. Scoreboard HEALTH INDEX shows e.g. `8 · Weak` (words, not `0.5`).
3. Story chart Y-axis is **Health Index (0–100)** with band regions.
4. CURRENT BAND = Weak / Soft / Strong / Hot.
5. 7D TREND = Rising or Softening.
6. Glossary still defines Health Index + bands.

## 5. Do not

- Do not re-add hex/color_map columns to SQL.
- Do not call `updateDashboard` again unless ready to re-link params afterward.
