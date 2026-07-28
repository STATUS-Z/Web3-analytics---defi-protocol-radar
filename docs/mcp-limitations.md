# MCP limitations (Dune)

Observed while shipping Protocol Signal Lab / DeFi Protocol Radar via `user-dune` MCP.

## Can

- `getDashboard` / `searchDuneDashboards` — title, slug, widgets, params, text
- `getDuneQuery` / `updateDuneQuery` — SQL + descriptions + parameters
- `createDashboard` / `updateDashboard` — layout (full widget replace)
- `generateVisualization` / `updateVisualization` — chart type + mappings (limited)
- `executeQueryById` / results — data checks

## Cannot / fragile

| Gap | Impact | Manual fix |
|-----|--------|------------|
| Series hex / theme colors | Band fills stay default until painted | Edit viz → Series colors |
| Partial widget patch | `updateDashboard` replaces **all** widgets when widget fields sent | Always `getDashboard` first; send full state |
| Widget ID stability | IDs regenerate on save | Re-link params after API layout writes |
| Param multi-query bind | One control ≠ all queries | Duplicate params or accept drift |
| True spider chart | No native radar | Line chart closed-loop hack |
| Screenshots | No MCP screenshot export | Capture in browser; store under `assets/` |
| Embed auth | Public dashboards only for anonymous embeds | Keep `isPrivate: false` |

## Operational rule

After any MCP `updateDashboard`:

1. Fetch live state again.
2. Re-link filters (especially `decomp_axis` → 7997415 / decomp widget).
3. Verify series colors on Health Index chart.
4. Update `docs/live-dashboard-snapshot.json` in this repo.
