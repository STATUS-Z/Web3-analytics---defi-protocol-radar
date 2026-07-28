# Widget ↔ query map

Live fetch: 2026-07-28 via `user-dune` MCP `getDashboard`  
Dashboard: https://dune.com/za_chain/defi-protocol-radar-1 · ID **216253**

## Visualization widgets

| Widget ID | Viz ID | Label | Zone | Query (primary) | Position |
|----------:|-------:|-------|------|-----------------|----------|
| 2287564 | 11980819 | RADAR | Crown | 7995136 | r6 c0 6×14 |
| 2287565 | 11982551 | WHO LEADS | Scoreboard | 7997414 | r22 c0 1×5 |
| 2287566 | 11982547 | HEALTH INDEX | Scoreboard | 7997414 | r22 c1 1×5 |
| 2287567 | 11982546 | MOMENTUM | Scoreboard | 7997414 | r22 c2 1×5 |
| 2287568 | 11982549 | MARKET PULSE | Scoreboard | 7997414 | r22 c3 1×5 |
| 2287569 | 11982550 | ANOMALY | Scoreboard | 7997418 | r22 c4 2×5 |
| 2287570 | 12019062 | 7D TREND | Story | 8034055 | r29 c0 2×4 |
| 2287571 | 12122499 | CURRENT BAND | Story | 8034055 | r29 c2 2×4 |
| 2287572 | 12019063 | AXIS LEADER | Story | 7997415 | r29 c4 2×4 |
| 2287573 | 11982552 | HEALTH INDEX chart | Story | 7997419 | r33 c0 4×10 |
| 2287574 | 11982548 | ASSET DECOMP | Context | 7997415 | r33 c4 2×10 |
| 2287575 | 11982553 | AUDIT | Vault | 7997416 | r51 c0 6×8 |
| 2287576 | 11980873 | HEARTBEAT | Vault | 7995854 | r59 c0 6×3 |

## Text widgets

| Widget ID | Role | Position |
|----------:|------|----------|
| 2287559 | Banner (how to read) | r1 c0 6×5 |
| 2287560 | Crown subtitle | r20 c0 6×2 |
| 2287561 | Story subtitle | r27 c0 6×2 |
| 2287562 | Glossary | r43 c0 6×6 |
| 2287563 | Vault audit note | r49 c0 6×2 |

## Param widgets (live)

All currently attach to query **7995136** / viz widget **2287564**:

| Key | Intended attach | Live attach | Status |
|-----|-----------------|-------------|--------|
| date_snapshot | Master radar | 7995136 / 2287564 | OK for Crown |
| protocols | Master (+ shared) | 7995136 / 2287564 | OK |
| selected_protocol | Master radar | 7995136 / 2287564 | OK |
| time_offset | Master radar | 7995136 / 2287564 | OK |
| decomp_axis | **7997415** / **2287574** | 7995136 / 2287564 | Needs re-link |
| widget | (prefer remove) | 7995136 / 2287564 | Legacy router |

**Warning:** Dune `updateDashboard` regenerates numeric widget IDs on every full save. Re-link params after API layout writes. See `docs/manual-ui-steps.md`.

## Machine-readable

`docs/live-dashboard-snapshot.json`
