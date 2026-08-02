# OHS Shield Tracker — Reporting (Prompt 14)

> All MVP1 reports with CSV/PDF export, history, and RBAC-scoped visibility (same as dashboards). MVP2/3 reporting excluded. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get` incl. new `pdf` dep, `build_runner`).

## Files
- domain: `report_models.dart` (types, filters, result, history item)
- data: `report_exporter.dart` (CSV pure + PDF via `pdf`), `report_repository.dart`
- presentation: `providers/report_providers.dart`, `screens/report_screen.dart`
- core: `ReportHistoryEntries` Drift table (schema v3)
- wiring: `/reports`; tests: `report_csv_test.dart`

## 1. MVP1 report catalogue
Hazard Register · Incident Log · CAPA Status · Inspection Summary · Risk Register. Each is a tabular `ReportResult` (columns + rows) rendered identically to CSV and PDF. (No MVP2/3 report types.)

## 2. RBAC visibility
Reports query the same RLS-scoped tables as the dashboards, so a report contains **exactly the rows the caller may see** (own→dept→site→enterprise). No per-role branching — the DB enforces it, matching Prompt 13.

## 3. Export
- **CSV**: pure `ReportCsv.build` (RFC-4180-ish escaping) — unit-tested.
- **PDF**: `pdf` package (`TableHelper.fromTextArray`, green header) — a titled, dated table.
- Files saved to `documents/reports/`; the path is returned (opening/sharing via `share_plus`/`open_filex` is an integration wiring step).

## 4. Report history & offline access
Every export is recorded in the local `ReportHistoryEntries` Drift table (type, title, format, path, timestamp) and listed on the screen. Because the files persist locally, **past reports are openable offline** — satisfying "Offline Access (cached reports)". Generating a *new* report needs connectivity (fresh data); the UI says so and still shows history.

## 5. Filters
Optional From/To date range applied to the report's natural date (reported/occurred/conducted/assessed); CAPA status report is unbounded by date.

## 6. Self-Check
| Requirement | Handling / test |
|---|---|
| All MVP1 reports | 5 `ReportType`s |
| CSV export | `ReportCsv.build` + `report_csv_test` (escaping) |
| PDF export | `ReportExporter.exportPdf` (`pdf`) |
| Report history | `ReportHistoryEntries` + screen list |
| RBAC scoping = dashboards | RLS-scoped queries |
| Offline access | saved files + history persist locally |
| Date filter | `ReportFilters.matches` + test |

## 7. Ledger note (pending approval)
- Reporting at `lib/features/reports`; 5 MVP1 report types; CSV (pure) + PDF (`pdf` dep added); local `ReportHistoryEntries` (Drift schema v3) = history + offline. RBAC via RLS. Sharing/opening files deferred to integration (share_plus/open_filex).

**End of Prompt 14 deliverable.**
