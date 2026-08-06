# OHS Shield Tracker — Build Decisions Ledger

> Carry **MVP1_2.md (Master Prompt) + this Ledger** into each follow-up prompt instead of pasting full prior outputs.
> Fill in blank slots as each prompt is approved. Section 2 values are copied from the Master Prompt — restated, not editable here.

> **CANONICAL SOURCE OF TRUTH (updated 2026-08-01):** `MVP1_2.md` (adds USER MANAGEMENT & PROVISIONING + 4 admin-only RBAC rows) and `MVP1_Follow_ups_1.md`. These supersede `MVP1_1.md` / `MVP1_Follow_ups.md` (pre-user-management). Follow-up sequence now inserts **Prompt 4C** (before Auth) and **Prompt 5A** (after Auth).

**Last updated after:** Prompt 18 (Deployment — approved) · **MVP1 BUILD SEQUENCE COMPLETE (Prompts 1–18 + 4C/5A/8A)**  ·  **Flutter SDK pinned to:** 3.24.5 (constraint `>=3.24 <4.0`)  ·  **Supabase project ref:** ___ (per-env, set at deploy)

---

## 1. Naming & Structure (set in Prompts 2A & 4A)
- **Table naming convention:** ___ (e.g. snake_case plural)
- **Table naming convention:** (D-schema-1) snake_case; tables plural, columns singular; UUID PKs (`gen_random_uuid()`); `created_at`/`updated_at` timestamptz; `is_`/`has_` booleans; `uq_`/`ck_`/`fk_`/`idx_`/`trg_` object prefixes.
- **Confirmed table list (20):** users, roles, user_roles, user_profiles, sites, departments, hazards, risk_assessments, incidents, investigations, corrective_actions, inspections, inspection_items, notifications, device_tokens, attachments, attachment_versions, audit_logs, sync_queue — *(additions)* **`companies`** (D1, tenant root — CONFIRMED 2A). *(4C column additions)* `user_roles.department_id` (nullable FK); `user_profiles.status` (+ invited_at/activated_at/deactivated_at). *(4C enum)* `user_status` (invited·active·suspended·deactivated).
- **Flutter folder root pattern:** `lib/{core, shared, features, services, repositories}` + `app.dart` — *(deviations)* none
- **Feature folder internal structure:** `features/<feature>/{presentation, application, domain, data}` (D8 — CONFIRMED Prompt 4A)
- **Provider naming convention:** repository providers `<feature>RepositoryProvider`; async state via codegen `@riverpod` Notifier classes `<Feature><Thing>Notifier` exposing `AsyncValue<T>`; derived values = `@riverpod` functions; core infra = hand-written `Provider`s (no codegen).
- **DTO ↔ Entity mapping convention:** DTOs in `data/` suffixed `Dto` (freezed + json_serializable, snake_case `@JsonKey`); mappers `XDto.toEntity()` / `XEntity.toDto()`; immutable freezed entities in `domain/`.
- **Error/Result convention:** `Result<T>` = `Ok`/`Err` (dependency-free) + `Failure` hierarchy (Network/Auth/Server/Cache/Validation/Permission/Unknown); `guardAsync` maps infra exceptions (PostgREST `42501` → `PermissionFailure`).
- **Source-linkage modelling (D2):** typed nullable FKs + CHECK (exactly one origin set); no untyped `(source_type, source_id)`. Applies to `investigations` (hazard_id?/incident_id?) and `corrective_actions` (hazard_id?/incident_id?/investigation_id?/inspection_item_id?). Hazard↔Incident via `hazards.source_incident_id?` + `incidents.source_hazard_id?`.

## 2. Locked Domain Values (restated from Master Prompt — do not redefine here)
- **Roles:** Employee, Supervisor, Safety Officer, Manager, Administrator
- **Risk bands:** 1–5 Low · 6–12 Medium · 13–17 High · 18–25 Critical
- **Incident severity:** Minor (Green) · Moderate (Amber) · Serious (Red) · Critical (Red, full intensity)
- **Hazard status:** Draft → Submitted → Assessment → Investigation → CAPA → Verification → Closed
- **Incident status:** Reported → Investigated → CAPA → Verified → Closed
- **CAPA status:** Created → Assigned → In Progress → Verification → Closed
- **Investigation status:** Open → In Progress → Pending Review → Completed
- **Inspection status:** Draft → In Progress → Submitted → Closed
- **Colour tokens:** Green `#2E7D32` · Amber `#F9A825` · Red `#C62828` · Blue `#1565C0` (brand accent `#923357` is non-semantic, decorative only)
- **Typography:** Inter (fallback Roboto) — H1 32/Bold · H2 24/SemiBold · H3 18/SemiBold · Body 14–16 · Caption 12
- **Spacing scale:** 4 · 8 · 12 · 16 · 24 · 32 · 40 · 64 (px)

## 3. Cross-Cutting Contracts (set in Prompts 1, 6, 15)
- **Attachment service API surface (Prompt 6):** `AttachmentRepository` / `AttachmentUseCases` — `upload({ownerType, ownerId, media/localPath, attachmentId?})` · `listForOwner(type,id)` · `listVersions(attachmentId)` · `preview(attachmentId,{versionId})→signedUrl` · `download(attachmentId,{versionId})→bytes` · `delete(attachmentId)` (logical). Version history: re-upload flags prior versions inactive + adds vN+1; never deleted. Storage path `<company_id>/<owner_type>/<owner_id>/<version_uuid>.<ext>`.
- **Reusable camera + GPS capture widget:** `AttachmentField` (`lib/features/attachments/presentation/widgets/attachment_field.dart`) backed by `MediaCaptureService` (camera/gallery/PDF + best-effort GPS). Offline: `PendingUploads` Drift table (schema v2) + `AttachmentUploadQueue` (D5 backoff).
- **Notification trigger hook names (stubbed 8–12 incl. 8A, consolidated 15):** (D7) `hazard.created` · `incident.created` · `risk.assessed` · `capa.assigned` · `capa.overdue` · `investigation.due` · `inspection.due`
- **Audit event helper signature:** (D6, conceptual) `recordAudit(entityType, entityId, action, before, after)` — actor + company derived from session/RLS context, never passed by client. IMPLEMENTED server-side as SECURITY DEFINER trigger `audit_row_change(entity_type)` (0012) attached per table (hazards done; others attach in their prompts). Actions: `<entity>.created` / `.updated` / `.status_changed` / `.deleted`.
- **Feature module conventions (from Prompt 7):** each business module lives at `lib/features/<name>` with `{domain, data, application, presentation}`; offline-writable creates/updates via `OfflineMutationService`; list/detail merge server + `AppDatabase.cachedByType(entity)`; per-record `SyncBadge` (`lib/shared/widgets/sync_status_badge.dart`); shared `RiskBand` at `lib/shared/domain/risk_band.dart`.
- **Deployment (Prompt 18):** `docs/18_deployment.md`; CI/CD `.github/workflows/ci.yml` (analyze/test/pgTAP → build AAB → `db push` + deploy 4 Edge Functions on tags); 4 envs = isolated Supabase + Firebase projects; config via `--dart-define-from-file` (`config/env/*.json`, gitignored); forward-only migrations + roll-forward recovery; first company/admin bootstrapped out-of-band via service role at go-live.
- **Testing (Prompt 17):** strategy `docs/17_testing.md`; runnable RBAC matrix test `test/security/rbac_matrix_test.dart`; pgTAP RLS sample `supabase/tests/rls_smoke_test.sql`. Coverage targets ≥70% domain/app, ≥50% overall (MVP1); client capability model + server RLS tested as two halves of the same matrix.
- **Audit Viewer module (Prompt 16):** `lib/features/audit`; read-only (`list`/`get` only — no mutation method; RLS blocks writes); SO/Manager/Admin via RLS `audit_select` (≥3) + router guard; filter by user/action/entity/date; `AuditDiff` before/after (ignores updated_at/version). Completes MVP Module 12. **All 11 feature modules implemented (Prompts 5–16).**
- **Notifications module (Prompt 15):** `lib/features/notifications`; `notify-fanout` Edge Function (recipient resolve + insert `notifications` + FCM push); `NotificationTriggers` upgraded from stub to real dispatch (dotted D7 → enum), same `fire()` signature so Prompts 7–13 callers deliver unchanged. In-app Center + unread badge + deep links (`NotificationDeepLink`); `FcmService` registers `device_tokens` (guarded). Push needs Firebase config + `FCM_SERVER_KEY` (Prompt 18); pref enforcement + cron overdue sweep = DEV.
- **Reporting module (Prompt 14):** `lib/features/reports`; 5 MVP1 reports (hazard register, incident log, CAPA status, inspection summary, risk register); CSV (pure `ReportCsv`) + PDF (`pdf` dep); RBAC via RLS-scoped queries (same as dashboards); local `ReportHistoryEntries` (Drift schema v3) = history + offline access; files saved to `documents/reports/` (share/open deferred to integration).
- **Dashboard module (Prompt 13):** `lib/features/dashboard`; **per-role scope via RLS** (own→dept→site→enterprise) + `DashboardScope` labels (no per-role query branching). `SafetyScore` heuristic (100 − 5·highRisk − 4·overdueCapa − 6·seriousIncident30d, clamp 0–100). Client-side aggregation (server `dashboard-aggregates` deferred = DEV). Offline snapshot cache (Drift `CachedRecords` entity `dashboard`). Signature widgets `RiskCompass`/`CurvedHeroHeader`/`KpiTile`/`MiniBarChart` (reuse MVP2/3).
- **Inspections module (Prompt 12):** `lib/features/inspections`; `ChecklistTemplates` per type; `InspectionScoring` (% pass, N/A excluded); statuses Draft→InProgress→Submitted→Closed; **`inspection-item-fail` Edge Function auto-creates Hazard + CAPA per failed item on submit (idempotent, service role, Supervisor+)**; CAPA linked via `inspection_item_id` (4th `CapaSourceRef`). Offline create/answer via outbox (`inspection`,`inspection_item`); submit online-only. Audit triggers 0015.
- **Edge Functions (server-side logic):** **`inspection-item-fail`** (12: fail→hazard+CAPA) · **`workflow-transition`** (8: authoritative Hazard close — SO+ + evidence + all-CAPAs-closed guards; extensible to Incident) · `dashboard-aggregates` · `notify-fanout` · **`user-admin`** (5A) · (optional, deferred) `access-token-hook`
- **Workflow engine (Prompt 8):** pure `HazardWorkflow` state machine (forward-only adjacent, role gates, close guard) + `HazardEscalation`. Non-close transitions via offline outbox; close routed to `workflow-transition` Edge Function (online-only). Notification stub `NotificationTriggers.fire(<D7 name>)` at `lib/services/notifications/notification_triggers.dart` (delivery in Prompt 15). `TransitionCheck` type (in `hazard_workflow.dart`) reused by other workflows.
- **CAPA module (Prompt 11):** `lib/features/capa`; `CapaWorkflow` (Created→Assigned→InProgress→Verification→Closed; assign⇒owner; **verification & closed = SO+** per RLS; close⇒verification evidence). `CapaSourceRef` = exactly one of hazard/incident/investigation/inspection_item. Kanban+List on Actions tab. `CapaEscalationRules` (due-date; overdue/critical→`capa.overdue`); `capa.assigned` on assign. Offline outbox (entity `corrective_action`); close needs connectivity.
- **Investigation module (Prompt 10):** `lib/features/investigations`; methods 5 Whys/Fishbone; analysis JSONB (both persist); `InvestigationWorkflow` (Open→InProgress→PendingReview→Completed, Supervisor+, **complete requires root cause + recommendations**); origin = exactly one hazard/incident; `generateCapa` (investigation_id FK). Timeline entity-derived (audit timeline = Audit Viewer / Prompt 16). Offline outbox (entity `investigation`).
- **Risk module (Prompt 9):** `lib/features/risk`; `RiskCalculator` = single scoring authority (score=L×S, band via shared `RiskBand.fromScore`, `reachableScores` = 14 values, `defaultCapaPriority(band)` Critical/High/Medium/Low). `risk_score`/`risk_band` are DB GENERATED columns — never sent on insert. Trigger `0014` syncs `hazards.risk_level` from latest assessment + audits. Offline draft via outbox (entity `risk_assessment`). `risk.assessed` fired on save.
- **Incident module (Prompt 8A):** `lib/features/incidents`; first-class, bidirectional Hazard↔Incident link (`source_hazard_id`/`source_incident_id`); `IncidentWorkflow` (Reported→Investigated→CAPA→Verified→Closed, same close guard, SO+); `workflow-transition` generalised to `entityType: hazard|incident`; witnesses POPIA-minimal JSONB; linkage engine `generateInvestigation`/`generateCapa` (typed FK, exactly-one-origin). Audit triggers on incidents/investigations/corrective_actions (0013). `NotificationTrigger.incidentCreated` fired on report.
- **Auth (Prompt 5):** feature at `lib/features/auth`; `AppUser`/`AppRole`/`UserStatus` entities; `authRoleRankProvider` = client role rank for UI + router guard; sign-in enforces active-status gate; session persistence + secure storage via `supabase_flutter` + `flutter_secure_storage`.
- **User activation (5A):** trigger `handle_user_confirmed` flips `user_profiles.invited → active` when `auth.users.email_confirmed_at` is set (invite acceptance).

## 4. Offline & Sync Decisions (set in Prompts 1 & 4B)
- **Conflict resolution rule:** (D4, IMPLEMENTED 4B) **LWW + audit trail** for `hazards`, `incidents`, `risk_assessments`, `investigations`, `inspections` (header); **field-level merge** (client-touched fields win, untouched keep server) for `corrective_actions` + `inspection_items`. Detection via `version` vs `base_version`.
- **Retry/backoff policy:** (D5, IMPLEMENTED 4B) exponential backoff — base 2 s, factor 2, max 5 attempts, cap 60 s, ±20% jitter; then `failed` (user-retryable via `syncNow`). Non-retryable: RLS `42501` + 4xx validation.
- **Sync status states in UI:** pending · syncing · synced · failed — *(deviations)* none
- **Local Drift tables mirroring `sync_queue`:** (4B) `SyncQueueEntries` (outbox mirror) + `CachedRecords` (generic offline cache + per-record status). Offline-writable entities: Hazard, Incident, Inspection, CAPA (+ inspection_item). Providers: `recordSyncStatusProvider`, `pendingSyncCountProvider`.

## 5. Security & RBAC Decisions (set in Prompts 1, 2B, 5)
- **RLS scoping claim source:** (D3, IMPLEMENTED in 0006) `app.*` `SECURITY DEFINER` helpers — `app.current_company_id()`, `app.current_site_id()`, `app.current_department_id()`, `app.user_rank()`, `app.has_min_rank(n)` — reading `user_profiles`/`user_roles` keyed on `auth.uid()`. JWT-claims hook deferred (DEV2).
- **RLS rank ladder:** employee=1 · supervisor=2 · safety_officer=3 · manager=4 · administrator=5. Visibility ladder: own(1)→dept(2)→site(3)→enterprise(4–5). Role write-gates enforced in `WITH CHECK` (close hazard/incident ⇒ ≥3; CAPA verification/closed ⇒ ≥3; manage user_roles ⇒ ≥5).
- **Storage (D-rls-1):** private `attachments` bucket; path `<company_id>/<owner_type>/<owner_id>/<version_uuid>.<ext>`; tenant isolation via `foldername[1]=company_id`; physical delete = SO+; logical delete stays app-layer.
- **Multi-site isolation columns:** `company_id` on all tenant tables; `site_id`/`department_id` where relevant — *(exceptions)* global reference tables (`roles`) are not tenant-scoped.
- **Audit-viewer access roles:** Safety Officer, Manager, Administrator (read-only)
- **Audit immutability (D6):** `audit_logs` = INSERT + SELECT only; no UPDATE/DELETE for any role. POPIA erasure via redaction of business rows, never audit-row deletion.
- **Secure storage mechanism:** (set 4A) `flutter_secure_storage` — Android `encryptedSharedPreferences`, iOS Keychain `first_unlock`. Auth tokens managed by `supabase_flutter`.

#### 5a. User Management & Provisioning (set in Prompt 4C, per MVP1_2.md)
- **Identity model — 3 layers:** `auth.users` (Supabase credentials) · `user_profiles` (app record, 1:1 by id; company/site/department, POPIA-minimal contact, `status`) · `user_roles` (scope-aware assignments).
- **Scope-aware `user_roles`:** `(user_id, role_id, site_id NULL, department_id NULL)`. NULL scope = company-wide; populated site/department restricts the role. `department_id` added in 4C (0009). Uniqueness via `UNIQUE NULLS NOT DISTINCT (user_id, role_id, company_id, site_id, department_id)`.
- **User lifecycle:** `invited → active → suspended → deactivated` (enum `user_status` on `user_profiles` + `invited_at`/`activated_at`/`deactivated_at`). **Never hard-delete a user** (retains historical ownership + audit); deactivation revokes session/blocks login only. `is_active` deprecated in favour of `status`.
- **Provisioning:** invite-based, **Administrator-only, no open self-registration**. Privileged ops (invite, role/scope change, deactivate, admin password reset) run via **Supabase Edge Functions using the service role** — never the client. Invite via `inviteUserByEmail` (built in Prompt 5A).
- **RBAC additions (4 admin-only rows, MVP1_2.md matrix):** Invite/Provision User · Assign/Change Role & Scope · Deactivate/Reactivate User · Reset User Password (admin-initiated) — all Administrator (rank 5) only, enforced at RLS + Edge Function.
- **User-table write posture (4C, 0010):** Administrator-only INSERT/UPDATE on `user_profiles` + `user_roles`, scoped to admin's own `company_id`; **no client DELETE** on any user table (mirrors audit immutability). Profile activation on invite-accept done by Edge Function (service role).
- **Licensing/billing/seats:** DEFERRED to MVP2. Build invite gate so a single seat-entitlement check can be inserted later; no billing logic in MVP1.
- **Claim derivation with multiple role rows:** `app.user_rank()` = max rank across the user's `user_roles` in their company (unchanged by scope columns); home site/department still read from `user_profiles`.

## 6. Output & Handoff Conventions (set once, applied everywhere)
- **Code emission format:** one file per block, prefixed `// path: lib/...`
- **Icon/asset handling:** source SVG wired in verbatim at `assets/branding/app_icon.svg` (Master Prompt Item 1a) — treated as fixed binary; never hallucinated, redrawn, or inline-approximated. Only permitted crops: full icon tile + isolated checkmark badge.
- **"Production-ready" interpretation:** review-ready first implementation requiring human compile + integration test before shipping.

## 8. Compile/Integration Pass (2026-08-01)
Ran on the installed toolchain **Flutter 3.44.6 / Dart 3.12.2** (newer than the pinned 3.24.5 target). Result: `flutter pub get` ✅, `build_runner build` ✅ (all freezed/json/riverpod/drift generated), `flutter analyze` ✅ **0 errors / 0 warnings** (292 info lints remain — trailing commas + SDK deprecations), `flutter test` ✅ **101/101 passed**.
**Adaptations made to compile on the newer SDK (revert on a pinned 3.24.x toolchain):**
- Bumped `flutter_riverpod`/`riverpod_annotation` → ^2.6.1, `riverpod_generator` → ^2.6.4, `drift`/`drift_dev` → ^2.21, `freezed` → ^2.5.8, `json_serializable` → ^6.9.0, `flutter_lints` → ^5.0.0.
- Removed `custom_lint`/`riverpod_lint` (their `analyzer ^6.x` pin is incompatible with Dart 3.12) + dropped the custom_lint plugin from analysis_options.
- `dependency_overrides: path_provider_android ">=2.2.0 <2.3.0"` (2.3.x pulls `jni`, whose archive won't fetch in this sandbox — Windows TLS revocation-check limit).
- Commented out the Inter `fonts:` block in pubspec (placeholder .ttf files not present; 'Inter' falls back until wired).
**Code fixes (keep — genuine):** `CardTheme`→`CardThemeData` (Flutter rename); `KpiSet.fromJson` num casts; dropped unused `cause` field from `Failure` (was illegal `[]`+`{}` ctor mix) + removed `cause:` args; `MediaCaptureService.capturePhoto/pickImage` marked `async`; removed 3 unused imports.

**Android build config (added; APK gated only by missing Android SDK in sandbox):**
- `flutter create --platforms=android --org com.ohsshield` scaffolded `android/` (namespace/appId `com.ohsshield.ohs_shield_tracker`); deleted the default template `test/widget_test.dart`.
- `AndroidManifest.xml`: added INTERNET, ACCESS_NETWORK_STATE, CAMERA, READ_MEDIA_IMAGES, READ_EXTERNAL_STORAGE(≤32), ACCESS_FINE/COARSE_LOCATION, POST_NOTIFICATIONS; camera feature optional; label "OHS Shield Tracker".
- `app/build.gradle.kts`: `minSdk = max(23, flutter.minSdkVersion)` (flutter_secure_storage), `multiDexEnabled = true`, three flavors `dev`/`uat`/`prod` (dimension `env`, appId suffixes). ⇒ builds must pass `--flavor <env>`.
- Firebase `com.google.gms.google-services` plugin lines added **commented** (app + settings gradle) — enable with a per-env `google-services.json`; base build works without it (FcmService degrades gracefully).
- `.gitignore` extended for android build/config + `google-services.json`.
- **To build once an Android SDK is present:** `flutter config --android-sdk <path>` (use JDK 17/21, not the installed JDK 25), then `flutter build apk --flavor dev --dart-define-from-file=config/env/dev.json`.

**Lint cleanup:** `dart fix --apply` → 272 fixes/71 files (trailing commas etc.) + manual fixes for `use_build_context_synchronously` (bottom-sheet callbacks capture `Navigator` before `await`) and `unawaited_futures` (`unawaited(context.push(...))`). Analyzer now **0 errors / 0 warnings / 9 info**. The remaining 9 are `deprecated_member_use` intentionally left — they're Flutter-3.44 deprecations (`SupabaseClient.anonKey`→publishableKey, `RadioListTile` groupValue/onChanged→RadioGroup, StreamProvider `.stream`) whose replacements don't exist on the pinned 3.24.5 target; fixing them would break the target SDK. Tests: **101/101 pass** after cleanup.

## 9. Device Testing & Hardening (2026-08-04)
On-device testing against the live Supabase backend (Samsung tablets + an Android emulator) surfaced and fixed several defects. Deployed the Edge Functions and verified the full hazard lifecycle end-to-end (report → advance → attach evidence → **close** via `workflow-transition`).

**Rendering / layout:**
- **Blank form/detail screens (11 screens):** the elevated/outlined button theme used `minimumSize: Size.fromHeight(52)` = `Size(∞, 52)`. A themed button inside a `Row` therefore demanded unbounded width, aborting the `Row`'s `RenderFlex` layout (`size: MISSING`) so the whole screen body never painted (AppBar only). Universal (not GPU) — proven via VM-service render/layer-tree dumps. **Fix:** bounded `minimumSize: Size(64, 52)`; full-width buttons still fill via `Column(stretch)`.
- FABs were hidden behind the floating bottom-nav pill (`extendBody`) — feed the pill's footprint back as bottom `viewPadding` in `AppShell`.
- Pushed detail/form sub-routes now render full-screen on the root navigator (`parentNavigatorKey: rootKey`), hiding the bottom pill.

**Sync / offline:**
- Sync engine + attachment upload queue now **start at app launch** (`ref.watch` in `OhsShieldApp`) with an initial drain — previously nothing synced (empty dashboard).
- Outbox now **drains immediately on enqueue** (`OfflineMutationService.onEnqueued` → `SyncEngine.drain()`), not only on connectivity events/launch (actions were stuck "pending").
- Hazard list is now resilient: caches server rows on read, re-queries when its tab regains focus (via `activeShellBranchProvider`), and its empty state is pull-to-refreshable — was showing a stale empty list.

**Auth:**
- The 11 screen action controllers changed from `FutureOr<void> build()` (AsyncNotifier — double-completed its internal `.future`) to `AsyncValue<void> build()` (plain Notifier). Fixes "Bad state: Future already completed" on every action.
- An expired/dead session now signs out locally so the router routes to login (was stranding the user on an authed screen showing "Not signed in").

**Backend / infra:**
- Applied the full schema (`apply_all.sql`) + bootstrapped the first Administrator (`bootstrap_admin.sql`); fixed `app.has_min_rank` param `smallint`→`integer` (SQL 42883).
- **Deployed all 4 Edge Functions** (`user-admin`, `workflow-transition`, `inspection-item-fail`, `notify-fanout`) via the Supabase CLI. All `verify_jwt=true`, app-invoked with the user JWT (no DB/webhook callers).
- **DEBUG-ONLY (remove before release — see memory):** `DevHttpOverrides` + `assets/dev/corporate_ca.pem` trust a corporate Cisco Umbrella TLS-inspection CA so the app reaches Supabase from an emulator behind the proxy. Gated to `kDebugMode`; release builds unaffected.

**Toolchain note:** briefly downgraded Flutter to 3.41.9 to test whether the blank screens were a 3.44 regression — they weren't (it was the theme bug above), so restored **3.44.6 / stable**.

## 10. Device Testing & Hardening — Round 2 (2026-08-05)
Continued on-device testing (Android emulator, live backend) fixed further defects and settled several product/UX decisions.

**Dashboard:**
- Stopped the cold-start flash of "Could not load dashboard · Bad state: Not signed in": `dashboardData` now `await`s `currentUserProvider.future` (it read `.valueOrNull`, which is null *while the profile loads*, not only when signed out) so it holds the loading state until the user is known.
- Auto-refreshes its aggregates when the Dashboard tab (branch 0) regains focus (mirrors the hazard-list re-query via `activeShellBranchProvider`), so hazard/CAPA changes on other tabs show without a manual pull-to-refresh.
- Scrolls clear of the floating nav pill (`ListView` bottom padding = nav footprint) — the Department risk ranking section was pinned behind the pill.
- Loading state is now a layout-shaped **shimmer skeleton** (shared `Shimmer`/`SkeletonBox`/`SkeletonList`/`SkeletonDetail` in `lib/shared/widgets/skeleton.dart`) instead of a bare spinner. Rolled out to the hazard/CAPA **list + detail** loading states too.

**Hazard / CAPA workflow & RBAC:**
- **Read-after-write:** `get()` (hazard + CAPA repos) now prefers an unsynced local write (cache `pending`/`syncing`) over the server, so a queued status transition shows on the **first** tap instead of appearing to need a second (the server returned the pre-edit row until the outbox drained; the second tap only worked because the first had synced).
- **CAPA overdue = the day *after* the due date** (was the due date itself). Shared day-granular `CorrectiveAction.isPastDue(due,{now})` used by the entity getter, `CapaEscalationRules`, and the dashboard overdue count. Previously `dueDate.isBefore(now)` with the date parsed as local midnight ⇒ overdue for the whole due day, and a CAPA "due today" was instantly overdue. *(Amends §3 CAPA module.)*
- **CAPA owner may Start work:** Assigned → In Progress is now permitted for the assigned owner without Supervisor rank (client `CapaGuardContext.isOwner`; RLS **migration 0016** adds `owner_id = auth.uid()` to the `capa_update` USING clause). Verification/Closed still require Safety Officer+ (WITH CHECK unchanged) — owners cannot self-verify or self-close. *(Amends §3 CAPA module + §5 rank gates.)*
- **Risk filter = "this band or more severe":** a hazard risk filter now matches high **and** critical (server `inFilter` + cached re-apply), so the dashboard High Risk KPI (which counts high+critical) matches the list it opens; an exact-`high` match was hiding Critical hazards.

**Hazard ↔ CAPA linkage (visibility):**
- Hazard detail now lists its linked corrective actions (open first) with tap-through; the "Add CAPA" button moved here from the mislabeled "Investigations" section. CAPA detail gained an "Open <source>" link to its originating hazard/incident/investigation. Backed by `CapaRepository.listForHazard` + `capasForHazardProvider`. Motivated by "all linked corrective actions must be closed first" being unactionable when the links weren't visible on either page.

**Hazards list / Actions UX:**
- Fixed the hazards list looking empty behind an invisible, unclearable risk filter arriving from the dashboard High Risk KPI: the **All** chip now clears risk too (and is "selected" only when no status/risk/mine filter is active); the empty state is filter-aware with a **Clear filters** action (`HazardFilter.isActive`).
- Actions (CAPA) page defaults to a **status-grouped vertical list** (each non-empty stage as a "Status · N" section); the Kanban stays behind the toggle and auto-scrolls to the first non-empty column (a lone open action in a later column looked like an empty board).

**Build:**
- `compileSdk` pinned to **36** (app `build.gradle.kts` + every Android library subproject via an `afterEvaluate` hook in the root `build.gradle.kts`) — a transitive plugin (`flutter_plugin_android_lifecycle`, via file_picker/image_picker) now requires apps/libraries to compile against API 36.

**Branding — launcher icon & splash (2026-08-06):**
- **Launcher/adaptive icon** generated from the branding tile via `flutter_launcher_icons` (legacy mipmaps + `mipmap-anydpi-v26` adaptive, background `#FBF9F1`), replacing the default Flutter icon. This also rebrands the **Android 12 splash**, which renders the launcher icon.
- **Native launch background = brand green** (`launch_background` drawables + `windowSplashScreenBackground`, light + night) so cold start no longer flashes white before Flutter draws.
- **In-app `SplashScreen`** (replaces the placeholder route): brand green, icon clipped to a squircle (`ContinuousRectangleBorder`) over a soft shadow, animated (scale+fade entrance, breathing pulse, expanding halo, staggered wordmark).
- **Splash hold** (`splashHold`, `lib/core/router/splash_gate.dart` + router `refreshListenable`): the session restores synchronously, so the redirect previously fired on the first frame and the splash never rendered. The countdown starts when the splash **builds** (not at app init) — the native launch screen already covers early startup, so an earlier timer elapsed before Flutter drew.
- **D-brand-1 (deviation):** branding renders the **raster** `assets/branding/app_icon.png`, not the SVG — `flutter_svg` ignores the gauge's `stroke-dasharray`/`dashoffset` and draws the ~74% safety arc as a **full circle**. Splash, login logo, and dashboard hero header/watermark all use the PNG; the SVG source is retained (un-bundled) as `app_icon_.svg`. Supersedes the §6 "source SVG wired in verbatim" note for on-screen rendering — the SVG remains the design source of truth.
- **Known limitation:** on Android 12+ the OS masks the splash icon to a **circle** (not overridable), so the sequence is OS circle → in-app squircle. An emblem-only adaptive foreground would make the circle read as intentional.

**Navigation shell completed (2026-08-06) — modules were built but unreachable:**
- The **More** tab was still the Prompt-4A `PlaceholderScreen`. Its branch registered routes for **Incidents, Investigations, Inspections, Reports, Notifications, Audit log and User & Access Administration**, but nothing navigated to them — so seven finished modules had **no entry point in the UI**. `CurrentUser.signOut()` was likewise never called from any screen, so there was no way to sign out or switch accounts (which also blocked testing lower-rank roles).
- **`MoreScreen`** (`lib/features/more/`) replaces the placeholder: signed-in identity (name · role · email), the seven destinations grouped Safety / Insights / Administration, and a confirmed sign-out. Entries are **role-gated to mirror the router guards + RLS** (audit ≥ Safety Officer rank 3, user admin = Administrator rank 5) so lower roles don't reach a dead end; RLS stays authoritative.
- Destinations open with **`context.push`**, not `go`: `go` replaces the branch location, leaving nothing to pop, so `AppBar` rendered **no back button** and the only exit was re-tapping the More tab. Push keeps them inside the More branch (bottom nav stays visible) and restores the back affordance.
- **`navSafeInsets()`** (`lib/shared/widgets/nav_safe_insets.dart`) applied to shell list screens that set an explicit `EdgeInsets.all(16)` (incidents, investigations, inspections, users, reports). A scroll view with `padding: null` inherits the MediaQuery bottom padding `AppShell` injects for the floating pill; an explicit padding opts out, so the last row could hide behind it. Audit + notifications use null padding and were already correct — verified on-device (content passing under the pill *mid-scroll* is intended, and is not the same defect).
- **Still stubbed:** `Profile` and `Settings` remain `PlaceholderScreen`s and are intentionally omitted from More rather than listed as dead ends.
- **Process note:** §9/§10 and the MVP1_2 status block had called the build "complete" while these modules were unreachable. Treat a module as done only when it is **navigable**, not merely implemented and routable.

## 7. Open Questions / Deviations Log
- **OQ1:** Confirm `companies` table addition (D1) at Prompt 2A.
- **OQ2:** Confirm typed-FK linkage vs. untyped polymorphic (D2) at Prompt 2A.
- **DEV1:** Supabase Realtime not used in MVP1 (read-models designed to allow it later without redesign).
- **DEV2:** JWT-claims access-token hook deferred in favour of `SECURITY DEFINER` helpers (D3).
- **D9 (deviation):** Incident witnesses/injured-party stored as POPIA-minimal JSONB on `incidents` (not a separate `incident_witnesses` table), to keep the mandated table set intact; visibility governed by the incident row's RLS. Revisit if per-field erasure/audit granularity is later required.
- **DEV3:** On tables lacking `department_id` (`investigations`, `corrective_actions`), supervisor SELECT scope falls back to **site** (not department). Documented in docs/02b.

---

**Governance note:** Section 2 values are copied from MVP1_1.md for convenience — restated, not editable here. If any must change, change MVP1_1.md and re-derive; never let the Ledger and Master Prompt diverge.
