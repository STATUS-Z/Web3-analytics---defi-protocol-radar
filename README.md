# DeFi Protocol Radar

**Live:** [dune.com/za_chain/defi-protocol-radar-1](https://dune.com/za_chain/defi-protocol-radar-1)  
**Dashboard ID:** `216253` · **Owner:** `za_chain` (ZA CHAIN ANALYTICS) · **Public**

Compare **Uniswap, Aave, Lido, Maker, and Curve** on one screen — eight axes, ghost trails, a 0–100 Health Index, and an audit vault. Built for curious readers and serious capital. No crypto fluff.

> Collapse the Dune sidebar. Dark mode recommended.

---

## What this is

**Protocol Signal Lab / DeFi Protocol Radar** is a Dune dashboard that answers one question in five seconds:

> Which protocol is healthiest right now, and is the set Weak / Soft / Strong / Hot vs its own recent history?

It does **not** invent TVL leaderboards or Twitter narratives. It builds an eight-axis radar per protocol, scores each day with shoelace polygon area, then ranks today's combined sector strength as a percentile over ~120 days. That percentile is the **Health Index (0–100)**.

---

## How to read (Crown → Scoreboard → Story → Context → Vault)

| Zone | What you look at | What you learn |
|------|------------------|----------------|
| **Crown** | Spider radar + ghosts + gray sector average | Who is strongest *now* across Liquidity · Efficiency · Revenue · Users · Health · Stickiness · Momentum · Whale |
| **Scoreboard** | Who Leads · Health Index · Momentum · Market Pulse · Anomaly | Plain-language headlines (e.g. `68 · Strong`, `Rising`, `Calm`, `STEADY`) |
| **Story** | Rising/Softening · Current band · Health Index over time | Is the *set* getting healthier? Where does today sit in Weak/Soft/Strong/Hot? |
| **Context** | One-axis bar chart | Why the Crown looks that way — pick Liquidity, Whale, etc. |
| **Vault** | Glossary · Audit matrix · Heartbeat | Definitions, raw 0–1 scores, chain freshness |

**Health Index bands (fixed):**

| Band | Range |
|------|-------|
| Weak | 0–24 |
| Soft | 25–49 |
| Strong | 50–74 |
| Hot | 75–100 |

**Formula (product truth — do not invent):**

```text
sector_area(day) = SUM(protocol radar shoelace areas)
health_index     = ROUND(100 * PERCENT_RANK() OVER (ORDER BY sector_area), 0)
```

`sector_area_raw` on the Health Index query is the pre-percentile shoelace sum for auditors.

---

## Repo map (pstack: usage first)

```text
Caller wants → Clone SQL → Fork on Dune → Keep Crown→Vault layout → Ship
```

| Path | Role |
|------|------|
| [`README.md`](README.md) | This page — GitHub audience entry |
| [`sql/`](sql/) | Live-synced DuneSQL (query ID in filename) |
| [`docs/architecture.md`](docs/architecture.md) | Pipeline, zones, ownership |
| [`docs/sql-cte-pipeline.md`](docs/sql-cte-pipeline.md) | CTE chain from raw trades → scores |
| [`docs/widget-query-map.md`](docs/widget-query-map.md) | Widget ↔ viz ↔ query IDs |
| [`docs/health-index.md`](docs/health-index.md) | Math, bands, chart encoding |
| [`docs/parameters.md`](docs/parameters.md) | Filter params + re-link notes |
| [`docs/visual-intelligence.md`](docs/visual-intelligence.md) | VI layout + 5-second story |
| [`docs/color-palette.md`](docs/color-palette.md) | UI-only hex (no SQL color columns) |
| [`docs/mcp-limitations.md`](docs/mcp-limitations.md) | What MCP can/can't do |
| [`docs/changelog.md`](docs/changelog.md) | Ship history |
| [`docs/live-dashboard-snapshot.json`](docs/live-dashboard-snapshot.json) | MCP fetch of live layout |
| [`assets/`](assets/) | Embeds / palette notes |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Fork-adapt on Dune |
| [`LICENSE`](LICENSE) | MIT |

---

## Queries (live)

| Query ID | Name | Zone |
|----------|------|------|
| [7995136](https://dune.com/queries/7995136) | Master Data Pipeline | Crown |
| [7997414](https://dune.com/queries/7997414) | Health Scoreboard | Scoreboard |
| [7997418](https://dune.com/queries/7997418) | Volatility Sentinel | Scoreboard |
| [7997419](https://dune.com/queries/7997419) | Health Index Timeline | Story |
| [8034055](https://dune.com/queries/8034055) | Trend + Health Band | Story |
| [7997415](https://dune.com/queries/7997415) | Axis Breakdown | Context |
| [7997416](https://dune.com/queries/7997416) | Protocol Audit Matrix | Vault |
| [7995854](https://dune.com/queries/7995854) | Chain Sync Status | Vault |

SQL files live under [`sql/`](sql/) as `{queryId}-{slug}.sql`.

---

## Design stack (applied)

- **Visual Intelligence** — First 5 seconds = Crown + Health Index band. Zones named like a terminal, not a dashboard of cards.
- **Anti-slop** — Plain words (`Rising` / `Softening`, `Weak`/`Hot`). No "robust synergy" copy. No hex columns in SQL.
- **pstack (architect)** — Module boundaries: raw → z-score → polar → shoelace → Health Index → widgets. Usage written before structure. Scrap wrong shapes (e.g. cryptic `0.5` / `UP` / `HOT` codes) and replace with readable scoreboard strings.

---

## Quick start (fork)

1. Open the [live dashboard](https://dune.com/za_chain/defi-protocol-radar-1).
2. Fork queries from [`sql/`](sql/) into your Dune account.
3. Rebuild widgets in Crown → Scoreboard → Story → Context → Vault order (see [`docs/visual-intelligence.md`](docs/visual-intelligence.md)).
4. Set series colors in the Dune UI — MCP cannot set hex ([`docs/color-palette.md`](docs/color-palette.md)).
5. After any `updateDashboard` API save, re-link params ([`docs/parameters.md`](docs/parameters.md)).

Full fork notes: [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Data sources (Ethereum Spellbook / decoded)

- `dex.trades` — Uniswap, Curve
- `lending.supply` — Aave, Maker (via spark mapping in pipeline)
- `lido_ethereum.steth_evt_submitted` — Lido
- `ethereum.blocks` — Heartbeat freshness

Proxy metrics (fees, TVL heuristics) are documented in SQL headers. Treat scores as **relative** within the selected set, not absolute USD truth.

---

## License

[MIT](LICENSE)
