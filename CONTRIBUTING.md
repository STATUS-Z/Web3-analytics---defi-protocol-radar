# Contributing / fork on Dune

## Who this is for

Analysts who want a local copy of DeFi Protocol Radar with different protocols, chains, or axes.

## Fork steps

1. **Clone this repo** for SQL + docs.
2. On [Dune](https://dune.com), create eight queries (or fewer if you drop Vault).
3. Paste from `sql/{id}-{name}.sql`. Rename params if needed, but keep names aligned across queries.
4. Create a new dashboard. Build zones in order: Filters → Banner → Crown → Scoreboard → Story → Context → Vault.
5. Add visualizations matching `docs/widget-query-map.md` (types: radar line, counters, area, bars, table).
6. Set series colors from `docs/color-palette.md`.
7. Wire params per `docs/parameters.md`.
8. Run all queries for a known-good `date_snapshot`.

## Adapting protocols

- Edit `CTE_1` / `daily` unions: swap Spellbook projects / decoded tables.
- Keep the **8-axis contract** or update `axis_def` everywhere (radar angles assume 8).
- Revisit fee/TVL heuristics — label them as proxies in query descriptions.

## Adapting Health Index

- Keep `PERCENT_RANK` + fixed bands unless you update banner, glossary, fills, and README together.
- Window length is `INTERVAL '120' DAY` in params CTEs.

## Pull requests to this repo

- Prefer SQL + docs in the same PR.
- No secrets (`.env`, API keys).
- No force-push to `main`.
- Match anti-slop tone: short sentences, no buzzword paste.

## Issues worth filing

- Param re-link drift after dashboard API saves
- Spellbook lag making a day look falsely Weak
- Protocol mapping bugs (e.g. Maker/spark)
