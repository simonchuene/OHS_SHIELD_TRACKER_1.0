# OHS Shield Tracker — MVP 1 Testing Strategy (Prompt 17)

> Implementation-ready QA plan. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`. Complements the per-feature tests already written under `test/`.
>
> **Status:** Draft for human approval.

## 0. Test pyramid & tooling
- **Unit** (most) → **Widget** → **Integration** (fewest). Backend: **pgTAP** for RLS/DB.
- Tooling: `flutter_test`, `mocktail` (fakes for repos/Supabase), `ProviderContainer` for Riverpod, `integration_test` for E2E, `pg_prove`/pgTAP for RLS, `flutter test --coverage` (target **≥70%** domain/application, **≥50%** overall for MVP1).
- All pure domain logic is already covered (risk bands, workflows, escalation, scoring, diff, deep links, CSV, lifecycle). This plan extends to widgets, integration, RBAC, sync, a11y, security, performance.

## 1. Unit test strategy
Focus on the pure, deterministic logic (no I/O):
| Area | Existing / planned test |
|---|---|
| Risk banding (1–25, reachable 14) | `test/features/risk/risk_calculator_test.dart`, `test/shared/risk_band_test.dart` |
| Hazard/Incident/CAPA/Investigation workflows + guards | `*_workflow_test.dart` (4 modules) |
| Escalation (hazard/CAPA) | `*_escalation_test.dart` |
| Inspection scoring (N/A excluded) + templates | `inspection_scoring_test.dart` |
| Sync conflict resolver + retry backoff | `test/services/sync/*` |
| Audit diff | `audit_diff_test.dart` |
| Report CSV + filters | `report_csv_test.dart` |
| Validators, AppRole/AppUser, DTO mappers | `validators_test`, `app_role_test`, `app_user_test`, `*_dto_test` |
Add: DTO round-trips for every module (incident/capa/inspection done; extend to risk/notification).

## 2. Widget test strategy
- Render each screen with `ProviderScope(overrides:[…fakes])`; assert states: **loading / data / empty / error / offline**.
- Key cases: Login validation (`login_screen_test`), hazard/incident report form validation, CAPA board Kanban↔List toggle, inspection run submit-gating (disabled until all answered), dashboard KPI render + drill-down nav, notification unread styling + tap→route.
- Golden tests (optional) for the signature components (RiskCompass, CurvedHeroHeader, KPI tile) in light + dark.

## 3. Integration (E2E) test strategy
`integration_test/` against a seeded Test Supabase project (or local `supabase start`). Cover the Success Criteria end-to-end:
1. Report hazard → assess → investigate → CAPA → verify → **close** (full lifecycle).
2. Report incident (each of 6 types) → link hazard → generate investigation + CAPA → close.
3. Inspection with a failed item → auto-created hazard + CAPA appear.
4. Offline report → reconnect → syncs (badge pending→synced).
5. Role-based navigation (Employee cannot reach Audit/User Admin).

## 4. Repository test strategy
- Fake `SupabaseClient` (mocktail) → assert repos return `Ok`/`Err` correctly and map `PostgrestException 42501 → PermissionFailure`, `SocketException → NetworkFailure` (via `guardAsync`).
- Offline-capable repos: assert create/update **enqueue** to the outbox and that list/detail **merge** cached rows.

## 5. RBAC test matrix (every role × action)
Runnable: **`test/security/rbac_matrix_test.dart`** encodes the Master Prompt matrix and asserts the `AppRole` capability model + rank thresholds. Server-side enforcement is proven by pgTAP (§7).

| Action | Emp | Sup | SO | Mgr | Admin |
|---|:--:|:--:|:--:|:--:|:--:|
| Report Hazard/Incident | ✅ | ✅ | ✅ | ✅ | ✅ |
| Perform Risk Assessment | ❌ | ✅ | ✅ | ✅ | ✅ |
| Conduct Investigation | ❌ | ✅ | ✅ | ✅ | ✅ |
| Create/Assign CAPA | ❌ | ✅ | ✅ | ✅ | ✅ |
| Verify & Close CAPA | ❌ | ❌ | ✅ | ✅ | ✅ |
| Close Hazard/Incident | ❌ | ❌ | ✅ | ✅ | ✅ |
| Conduct Inspections | ❌ | ✅ | ✅ | ✅ | ✅ |
| View Dept records | ❌ | ✅ | ✅ | ✅ | ✅ |
| View Site/Enterprise | ❌ | ❌ | ✅ | ✅ | ✅ |
| Manage Users & Roles | ❌ | ❌ | ❌ | ❌ | ✅ |
| View Audit Log | ❌ | ❌ | ✅ | ✅ | ✅ |
| Invite/Provision · Assign Role · (De)activate · Reset PW | ❌ | ❌ | ❌ | ❌ | ✅ |

Each row is tested twice: **client** (capability offered?) + **server** (RLS/Edge Function accepts/denies).

## 6. Offline sync tests (incl. conflict resolution)
- **Create offline → sync**: outbox pending → drain → server row → cache `synced`.
- **Update no-conflict**: version match → PATCH applied.
- **LWW conflict** (hazard/incident/risk/investigation): concurrent server edit newer → `AcceptServer` (local dropped, converged); local newer → `ApplyLocal`.
- **Field-merge** (CAPA/inspection_item): two different fields edited → both survive.
- **Retry/backoff** (D5): failure schedules retry with exponential delay; exhausts to `failed`; `syncNow` re-arms.
- **Attachment queue**: offline capture → `PendingUploads` → drain uploads → history version created.
(Resolver + retry already unit-tested; add an integration test driving the engine against a fake remote.)

## 7. Security tests (RLS bypass / auth edge cases)
Sample suite: **`supabase/tests/rls_smoke_test.sql`** (pgTAP) — audit immutability (no UPDATE/DELETE), employee cannot insert risk assessments, cross-company isolation returns 0 rows, Supervisor cannot close a hazard, SO can read audit while Employee sees none, non-admin cannot grant roles. Extend to **every** matrix cell.
Auth edge cases (widget/integration): deactivated/suspended account blocked at login; session expiry → redirect to `/login`; role guard on `/audit` and `/admin/**`; privileged ops require connectivity; service-role key never present in the client bundle (build-artifact scan).

## 8. Accessibility tests (WCAG 2.1 AA)
- `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` on Login, Dashboard, Hazard report, CAPA board.
- Verify ≥44×44 touch targets (pill nav, chips, KPI tiles), semantic labels on icon-only controls, colour never the sole signal (pills pair dot+icon+label), text scales with OS setting, and AA contrast in **both** light and dark.

## 9. Performance tests (Master Prompt targets)
| Target | Method |
|---|---|
| Dashboard load < 3 s | integration timing on seeded data (50 users, ~500 rows/entity); if exceeded, enable the `dashboard-aggregates` Edge Function/materialized view |
| Search results < 2 s | list-filter timing |
| Navigation < 300 ms | route transition timing |
| Offline sync non-blocking | assert UI thread not blocked during drain (writes return immediately) |
Use `flutter test integration_test --profile` + Timeline traces; watch jank on large lists (row height 56, lazy `ListView`).

## 10. UAT scenarios (business acceptance)
Scripted for each role covering Success Criteria #1–#10: report→assess→investigate→CAPA→verify→close a hazard; report+link an incident; run an inspection with a fail; view role-scoped dashboard; export a report; receive + deep-link a notification; Administrator invites/deactivates a user; Safety Officer reviews the audit trail. Each with pass/fail + evidence capture.

## 11. Regression checklist (pre-release)
- [ ] All unit/widget tests green; coverage thresholds met.
- [ ] pgTAP RLS suite green (every matrix cell).
- [ ] Offline: create/edit offline → reconnect → syncs; conflict resolves; failed → retry.
- [ ] Auth: login/logout, deactivated blocked, session persist/expiry, role guards.
- [ ] Full hazard + incident lifecycles close only with evidence + closed CAPAs.
- [ ] Inspection fail → hazard + CAPA generated (idempotent).
- [ ] Dashboard scoped per role; drill-downs work; offline cached values shown.
- [ ] Reports export CSV/PDF; history persists; RBAC-scoped rows.
- [ ] Notifications deliver in-app; deep links route; badge updates.
- [ ] Audit viewer read-only; before/after diff correct; SO+ only.
- [ ] A11y guidelines pass (light + dark); performance targets met.
- [ ] No secrets in client bundle; icon rendered from `assets/branding/app_icon.svg`.

## 12. Ledger note (pending approval)
- Test strategy at `docs/17_testing.md`; RBAC matrix test `test/security/rbac_matrix_test.dart`; RLS pgTAP sample `supabase/tests/rls_smoke_test.sql`. Coverage targets: ≥70% domain/application, ≥50% overall (MVP1). CI runs `flutter test` + `pg_prove` (Prompt 18).

**End of Prompt 17 deliverable.**
