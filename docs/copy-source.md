# Protocol Signal Lab — Final Copy (2026-07-28)

Dashboard: https://dune.com/za_chain/protocol-signal-lab-defi-health-dashboard  
ID: **216253**

Tone: Visual Intelligence (Crown → Scoreboard → Story → Context → Vault) + anti-slop.  
Audience: curious DeFi readers + serious capital. No crypto fluff.

---

## Top-of-page banner (text widget)

```markdown
### Protocol Signal Lab
Compare Uniswap, Aave, Lido, Maker, and Curve on one screen — for curious readers and serious capital.

**Health Index (0–100)** = where today’s combined radar strength ranks vs the last ~120 days.
**Bands:** Weak 0–24 · Soft 25–49 · Strong 50–74 · Hot 75–100.

**How to read**
1. **Crown** — Who is strongest now (radar + ghosts + gray sector average)
2. **Scoreboard** — Who Leads · Health Index · Momentum · Market Pulse · Anomaly
3. **Story** — Rising or Softening? Which band? Index over time
4. **Context** — One axis, bar by bar (why the Crown looks that way)
5. **Vault** — Glossary, audit scores, data heartbeat
```

Position: `row 1, col 0, sizeX 6, sizeY 5` (filters stay row 0; Crown radar shifts down).  
Live text widget ID after ship: **2287559**.

---

## Zone text widgets (refined)

### Crown subtitle
```markdown
**Crown — Who is healthiest right now?** Larger polygons = stronger. Gray = sector average. Ghosts = 7/30/90d ago.

**Axes:** Liquidity · Efficiency · Revenue · Users · Health · Stickiness · Momentum · Whale
```

### Story subtitle
```markdown
**Story — Is the set getting healthier?** Health Index (0–100) ranks today’s combined radar strength vs ~120 days. **Bands:** Weak 0–24 · Soft 25–49 · Strong 50–74 · Hot 75–100. Horizontal lines = band edges.
```

### Glossary (Vault)
```markdown
### New to DeFi? Start here.

| Term | Definition |
|------|------------|
| **Health Index (0–100)** | Where today’s overall protocol strength ranks vs ~120 days. 75+ = Hot; under 25 = Weak. |
| **Health bands** | Weak · Soft · Strong · Hot — plain words for the index. |
| **Protocol** | A DeFi app (Uniswap, Aave, etc.) where users trade, borrow, or earn. |
| **Ghost Trail** | Faded radar from 7/30/90 days ago. Expanding = growth. |
| **Sector Average** | Gray benchmark polygon — compare any protocol vs the group. |
| **Market Pulse** | Calm / Mixed / Stressed — how unusual today’s cross-protocol spread is. |

**What to do next:** Scan the radar → read Health Index + band → check Rising/Softening → drill one axis in Context.
```

### Vault audit note
```markdown
**Vault — Audit Trail:** Raw scores behind the radar. Trust, but verify. Highest per column = strongest on that metric; lowest = weakest. `sector_area_raw` on the Health Index query is the pre-percentile shoelace sum for auditors.
```

---

## Query descriptions (Dune `description` field)

| Query ID | Name | Description |
|----------|------|-------------|
| **7995136** | Master Data Pipeline | Eight-axis radar for Uniswap, Aave, Lido, Maker, Curve. Larger polygons = stronger. Gray = sector average. Ghosts = 7/30/90d ago. Powers The Crown. |
| **7995854** | Chain Sync Status | Freshness check. Latest Ethereum block + when this page last queried. Higher block = newer data. |
| **7997414** | Health Scoreboard | Scoreboard in plain words: Who Leads, Health Index (0–100 · Weak/Soft/Strong/Hot), Momentum Rising/Softening, Market Pulse Calm/Mixed/Stressed. |
| **7997415** | Axis Breakdown | One axis at a time. Bars rank protocols on Liquidity, Efficiency, Revenue, Users, Health, Stickiness, Momentum, or Whale. Pick the axis in filters — Context zone. |
| **7997416** | Protocol Audit Matrix | Vault table. Relative strength 0–1 for every protocol × every axis on the snapshot day. Highest in a column wins that metric. |
| **7997418** | Volatility Sentinel | Anomaly card. STEADY when pack strength is normal vs its 7-day average. SPIKE when it jumps unusually. Scoreboard sentinel. |
| **7997419** | Health Index Timeline | Health Index over time (0–100). Percentile of daily sector radar area vs ~120 days. Band fills: Weak · Soft · Strong · Hot. Story chart. |
| **8034055** | Trend + Health Band | 7-day Health Index move: Rising or Softening, plus current band (Weak/Soft/Strong/Hot). Story badges. |

---

## Product truth (do not invent)

- Health Index = `ROUND(100 * PERCENT_RANK() OVER (ORDER BY sector_area), 0)` where `sector_area` = sum of protocol radar shoelace areas.
- Bands fixed: Weak 0–24 · Soft 25–49 · Strong 50–74 · Hot 75–100.
- No hex/color_map columns in SQL.
