# OHS Shield Tracker — Hazard Management (Prompt 7)

> First business module. Consumes the shared Attachment service (Prompt 6), the offline sync engine (4B), and audit (new trigger). Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`. The lifecycle **state machine + transitions** are Prompt 8; this module covers capture/CRUD/list/detail.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`, migrations `0012`).

## Files
- shared: `lib/shared/domain/risk_band.dart`, `lib/shared/widgets/sync_status_badge.dart`
- domain: `entities/{hazard_category, hazard_status, hazard, hazard_filter}.dart`, `repositories/hazard_repository.dart`
- data: `hazard_dto.dart`, `hazard_repository_impl.dart`
- application: `hazard_use_cases.dart`
- presentation: `providers/hazard_providers.dart`, `widgets/hazard_ui.dart`, `screens/{hazard_list, hazard_report, hazard_detail}_screen.dart`
- server: `supabase/migrations/0012_audit_triggers.sql`; core: `app_database.dart` `cachedByType`
- tests: `test/shared/risk_band_test.dart`, `test/features/hazards/hazard_dto_test.dart`

## 1. Capture & CRUD
- **Report** (`HazardReportScreen`): title (required, ≤120), category (8 locked), description, GPS capture, photos/PDF via the shared picker; **Submit** → `submitted`, **Save draft** → `draft`.
- **List** (`HazardListScreen`): search + status/"Mine" chips; rows show duotone category badge, status/risk pill, and a **per-record sync badge**; empty state uses the Item-7 microcopy.
- **Detail** (`HazardDetailScreen`): status stepper, details, embedded `AttachmentField`, sync line, and a linkage placeholder (Risk/Investigation/CAPA arrive with the workflow).

## 2. Photo upload & GPS
Uses Prompt 6 directly: `MediaCaptureService` (camera/gallery/PDF + GPS) → captured media uploaded to the new hazard's id via `AttachmentField`/`AttachmentController` (owner = `hazard`). GPS is stored on the hazard row (`latitude`/`longitude`) and optionally as media metadata.

## 3. Offline support
- **Create/update** go through the 4B outbox (`OfflineMutationService.enqueueCreate/Update`, entity `hazard`) — the hazard appears immediately with a `pending` badge and syncs on reconnect (LWW, D4).
- **List/detail** merge server (RLS-scoped PostgREST) with locally-cached rows, so offline-created hazards are visible before they sync; falls back to cache-only when the server is unreachable.

## 4. Supabase integration & RBAC
- Reads/writes via PostgREST; RLS (2B) enforces the own→dept→site→enterprise visibility ladder and "any role may report". Reporter defaults company/site/department from the signed-in `AppUser`.

## 5. Audit logging
- `0012_audit_triggers.sql` adds a reusable `audit_row_change()` SECURITY DEFINER trigger, attached to `hazards`. Every INSERT/UPDATE writes an immutable `audit_logs` row with before/after; status changes are tagged `hazard.status_changed`. Because audit is server-side, offline-created hazards are audited when they sync (the actual INSERT).

## 6. Business rules
| Rule | Handling |
|---|---|
| Hazard lifecycle compliance | status enum + stepper now; transition guards in Prompt 8 |
| Risk / Investigation / CAPA linkage | FK columns exist (2A); surfaced on detail as those modules land (8–11) |
| Multi-site support | company/site/department on every hazard; RLS scoping |

## 7. Self-Check
| Constraint | Check |
|---|---|
| 8 categories, 7 statuses = locked | `HazardCategory`/`HazardStatus` mirror enums; DTO round-trip test |
| Risk bands 1–25 no gaps | `RiskBand.fromScore` test (boundaries 5/6/12/13/17/18/25) |
| Offline create visible pre-sync | list merges `cachedByType('hazard')` |
| Audit on every write | trigger on hazards (INSERT/UPDATE) |
| Icon by path / attachments reused | `AttachmentField` embedded, no bespoke upload |

## 8. Ledger note (pending approval)
- Hazard module at `lib/features/hazards`; shared `RiskBand` (`lib/shared/domain/risk_band.dart`) reused by Risk (Prompt 9).
- Reusable `SyncBadge` (`lib/shared/widgets/sync_status_badge.dart`).
- Audit: `audit_row_change(entity_type)` trigger pattern (attached per table); hazards attached in 0012.

**End of Prompt 7 deliverable.**
