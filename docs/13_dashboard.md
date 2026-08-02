# OHS Shield Tracker — Dashboard (Prompt 13)

> The signature mobile executive dashboard (curved hero + Risk Compass + KPI row), scoped per role. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`).

## Files
- domain: `safety_score.dart`, `dashboard_data.dart`, `dashboard_scope.dart`
- data: `dashboard_repository.dart`
- presentation: `providers/dashboard_providers.dart`, `widgets/{risk_compass, curved_hero_header, kpi_tile, mini_bar_chart}.dart`, `screens/dashboard_screen.dart`
- wiring: Dashboard tab route
- tests: `safety_score_test.dart`

## 1. Role-scoped by construction
The Prompt 13 scope table (Employee=personal · Supervisor=dept · SO=site · Manager/Admin=enterprise) is realised **through RLS**: the same aggregation queries return only rows the caller may see (the own→dept→site→enterprise visibility ladder from 2B). `DashboardScope` supplies the scope **label** and hides dept-ranking/system-health for lower roles. No per-role query branching is needed — the DB enforces it.

## 2. KPIs & aggregation
`DashboardRepository.load` runs RLS-scoped selects and computes: Open Hazards · High-Risk Hazards · Open CAPAs · Overdue CAPAs · Incidents(30d) · Near Misses(30d) · Serious Incidents(30d) · CAPA closure rate · Inspection completion rate · Department risk ranking · 6-week incident trend. (Client-side aggregation is fine at 10–50-user scale; a `dashboard-aggregates` Edge Function / materialized view is a deferred perf optimisation — **DEV**.)

## 3. Signature UI (locked design)
- **Curved hero header** (Item 4/4a): green gradient + shallow convex bottom, logo chip + two-line wordmark, avatar with progress-ring frame, left-aligned greeting + scope, low-opacity brand watermark (real icon asset).
- **Safety Score card** (Item 3/3a): two-column — context/trend text left, **Risk Compass** right (segmented Low/Med/High/Critical arcs, centre tabular numeral + checkmark badge), overlapping the header by ~half.
- **KPI row** (Item 7a): four tiles (duotone badge · oversized tabular numeral · label · semantic underline).
- Rate cards, incident-trend bars, department risk ranking bars.

## 4. Safety Score (MVP heuristic)
`score = clamp(100 − 5·highRiskHazards − 4·overdueCapas − 6·seriousIncidents30d, 0, 100)`. Deterministic and testable; documented as an MVP composite (weights tunable). Shown in the Risk Compass.

## 5. Offline & drill-down
- **Offline**: each successful load caches a `DashboardData` JSON snapshot (Drift `CachedRecords`, entity `dashboard`); when the server is unreachable, the last snapshot renders with a "Showing last synced data" banner.
- **Drill-down**: KPI tiles navigate to the relevant tab (High Risk pre-sets the hazard risk filter).

## 6. Self-Check
| Requirement | Handling / test |
|---|---|
| Per-role scope (5 roles) | RLS visibility ladder + `DashboardScope`; `safety_score_test` (labels + gating) |
| KPI set incl. closure/completion rates | `DashboardRepository` |
| Risk Compass (not a plain donut) | `RiskCompass` CustomPaint |
| Curved hero + KPI row + tabular numerals | signature widgets |
| Offline last-known values | JSON cache + banner |
| Safety score deterministic | `safety_score_test` |

## 7. Ledger note (pending approval)
- Dashboard at `lib/features/dashboard`; role scope via RLS + `DashboardScope`; `SafetyScore` heuristic (5/4/6 weights); client-side aggregation (server `dashboard-aggregates` deferred = DEV); offline snapshot cache (entity `dashboard`). Reusable `RiskCompass`, `CurvedHeroHeader`, `KpiTile`, `MiniBarChart` for MVP2/3.

**End of Prompt 13 deliverable.**
