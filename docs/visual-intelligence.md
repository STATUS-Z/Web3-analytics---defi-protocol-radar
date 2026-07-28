# Visual Intelligence layout

Applied: Visual Intelligence skill — Protocol Health pattern.  
Anti-slop gate on all user-facing copy.  
pstack architect: zone modules before widgets.

## First 5 seconds

1. Banner names the product and bands.
2. Crown radar shows who is largest now.
3. Scoreboard Health Index states Weak / Soft / Strong / Hot.

If a stranger cannot answer "who's healthy?" and "is the set hot or weak?" in five seconds, the layout failed.

## Zone contract

```text
Filters → Banner → Crown → Scoreboard → Story → Context → Vault
```

| Zone | Job | One headline |
|------|-----|--------------|
| Crown | Who wins *now* | Larger polygons = stronger |
| Scoreboard | Plain facts | Who Leads · Index · Momentum · Pulse · Anomaly |
| Story | Direction | Rising or Softening? Which band? |
| Context | Why | One axis, bar by bar |
| Vault | Trust | Glossary · audit · heartbeat |

## Do / Don't

**Do**

- One story per zone.
- Ghost trails for time (7/30/90d), not extra charts in Crown.
- Gray sector average as the only benchmark polygon.
- Plain band words everywhere the index appears.

**Don't**

- Card grids of unrelated KPIs in the first viewport.
- Hex / neon columns in SQL.
- Purple-glow AI-default themes for series colors.
- Cryptic codes (`0.5`, `UP`, `HOT`) without words.
- Overlay badges floating on radar media.

## Live positions

See `docs/widget-query-map.md` and `docs/live-dashboard-snapshot.json`.

## Banner (live text widget 2287559)

Opens with **Protocol Radar**, Health Index definition, bands, and the five-step read order. Ends with sidebar + dark mode tip.

## Series colors (UI)

| Series | Hex |
|--------|-----|
| Weak fill | `#DC3545` |
| Soft fill | `#FD7E14` |
| Strong fill | `#0DCAF0` |
| Hot fill | `#19FF85` |
| Health Index | `#FFFFFF` |
| Decomp accent | `#FD7E14` |

Protocol series palette notes: `docs/color-palette.md`.
