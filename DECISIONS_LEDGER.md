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
- **Notification trigger hook names (stubbed 8–12 incl. 8A, consolidated 15):** (D7) `hazard.created` · `incident.created` · `risk.assessed` · `capa.assigned` · `capa.overdue` · `investigation.due` · `inspection.due` **(+ `capa.verification_due` added 2026-08-16 — see §18.)**
- **Audit event helper signature:** (D6, conceptual) `recordAudit(entityType, entityId, action, before, after)` — actor + company derived from session/RLS context, never passed by client. IMPLEMENTED server-side as SECURITY DEFINER trigger `audit_row_change(entity_type)` (0012) attached per table (hazards done; others attach in their prompts). Actions: `<entity>.created` / `.updated` / `.status_changed` / `.deleted`.
- **Feature module conventions (from Prompt 7):** each business module lives at `lib/features/<name>` with `{domain, data, application, presentation}`; offline-writable creates/updates via `OfflineMutationService`; list/detail merge server + `AppDatabase.cachedByType(entity)`; per-record `SyncBadge` (`lib/shared/widgets/sync_status_badge.dart`); shared `RiskBand` at `lib/shared/domain/risk_band.dart`.
- **Deployment (Prompt 18):** `docs/18_deployment.md`; CI/CD `.github/workflows/ci.yml` (analyze/test/pgTAP → build AAB → `db push` + deploy 4 Edge Functions on tags); 4 envs = isolated Supabase + Firebase projects; config via `--dart-define-from-file` (`config/env/*.json`, gitignored); forward-only migrations + roll-forward recovery; first company/admin bootstrapped out-of-band via service role at go-live.
- **Testing (Prompt 17):** strategy `docs/17_testing.md`; runnable RBAC matrix test `test/security/rbac_matrix_test.dart`; pgTAP RLS sample `supabase/tests/rls_smoke_test.sql`. Coverage targets ≥70% domain/app, ≥50% overall (MVP1); client capability model + server RLS tested as two halves of the same matrix.
- **Audit Viewer module (Prompt 16):** `lib/features/audit`; read-only (`list`/`get` only — no mutation method; RLS blocks writes); SO/Manager/Admin via RLS `audit_select` (≥3) + router guard; filter by user/action/entity/date; `AuditDiff` before/after (ignores updated_at/version). Completes MVP Module 12. **All 11 feature modules implemented (Prompts 5–16).**
- **Notifications module (Prompt 15):** `lib/features/notifications`; `notify-fanout` Edge Function (recipient resolve + insert `notifications` + FCM push); `NotificationTriggers` upgraded from stub to real dispatch (dotted D7 → enum), same `fire()` signature so Prompts 7–13 callers deliver unchanged. In-app Center + unread badge + deep links (`NotificationDeepLink`); `FcmService` registers `device_tokens` (guarded). Push needs Firebase config + `FIREBASE_SERVICE_ACCOUNT` (Prompt 18; **amended by §11** — originally recorded as `FCM_SERVER_KEY`, a credential type Google has since retired); pref enforcement + cron overdue sweep = DEV.
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

## 11. Push Delivery — FCM HTTP v1 Migration (2026-08-14)

Reconstituted the build on a new workstation and, while verifying the notification path, found that the deferred push wiring was not merely unexecuted — **its remediation plan was stale**.

**The defect.** `notify-fanout` posted to `https://fcm.googleapis.com/fcm/send` authorised by `FCM_SERVER_KEY`. That is the **legacy FCM HTTP API, retired by Google in 2024**. §Notifications (Prompt 15) and `docs/18_deployment.md` both recorded push as "waiting on `FCM_SERVER_KEY`" — a credential that can no longer be issued. So push was non-functional on **Android as well as iOS**, and the `if (FCM_KEY)` guard made the failure silent: with no key set, the send was skipped rather than erroring, and `notify-fanout` still returned `ok: true`.

**The fix.** New `supabase/functions/notify-fanout/fcm.ts` implements FCM **HTTP v1**:
- OAuth2 bearer minted from a service account (`FIREBASE_SERVICE_ACCOUNT`): RS256-signed JWT via WebCrypto → token exchange at `oauth2.googleapis.com/token`. Signing key imported once per instance; access token cached and refreshed 60 s early (instances are reused across invocations).
- Per-platform payload: `android.priority` HIGH/NORMAL and `apns.headers.apns-priority` 10/5, driven by the `notification_priority` enum (`high`/`critical` → high). `data` values coerced to strings, as v1 requires — `FcmService._route` reads `entityType`/`entityId` back out for the deep link.
- **No `channel_id`** is sent: the app declares no notification channel, and naming a non-existent one suppresses the notification on Android 8+. FCM's default channel is the correct fallback.
- Sends run concurrently (`Promise.allSettled`) rather than sequentially, and a token FCM rejects as `UNREGISTERED` (404) / `INVALID_ARGUMENT` (400) is set `is_active = false`, so a dead device stops costing a send on every fan-out.
- Missing/malformed config still degrades to a silent no-op — the graceful-degradation property from §8 is preserved, and in-app remains the guaranteed channel.

**Deviation from house style:** the other three Edge Functions are single-file `index.ts`. The OAuth2/JWT machinery is split into a sibling `fcm.ts` so `index.ts` stays about fan-out; both files deploy as one function.

**Toolchain added (same day).** Deno 2.9.5 (winget `DenoLand.Deno`) and Supabase CLI 2.114.0 (official GitHub release `supabase_2.114.0_windows_amd64.zip`, SHA256 verified against the release `checksums.txt`, extracted to `%LOCALAPPDATA%\Programs\supabase` and added to the **user** PATH). Edge Functions had never been statically checked on any workstation before this.

**Verification status — static green, delivery still unproven.**
- `deno check` passes on `notify-fanout` **and** on all three pre-existing functions (`user-admin`, `workflow-transition`, `inspection-item-fail`) — a first baseline for the function suite.
- `deno lint` is clean on `fcm.ts`. Three `no-explicit-any` findings remain in `index.ts` (lines 50, 73×2), all **pre-existing** and left alone; the one this change would have added was typed out instead. Deno lint is not in CI (`ci.yml` runs `flutter analyze`/`test` + pgTAP only) — these are advisory.
- JWT assembly and PKCS#8 import validated under Node 24 (same WebCrypto/`btoa`/`atob` globals) against a throwaway RSA-2048 keypair: signature verifies, segments base64url-clean, escaped-newline PEM defence imports.
- **Not deployed. The FCM send path has never spoken to Google** — that needs a real service account, `google-services.json`, and a device token. Per the lesson below, treat push as unproven until a message is observed arriving on a handset.

**Lesson — verify at the delivery boundary, not the implementation boundary.** This is the §10 process note one layer out. There, seven modules were implemented and routable but not *navigable*. Here, push was implemented, deployed and genuinely invoked (`NotificationTriggers` really does call the function) but the final hop targeted an API that no longer exists. Both were recorded as done at the layer where the code stops, not the layer where the user receives something. Extend the §10 rule: a channel is done when a message **arrives**, and any credential-gated path that fails silently must be treated as unproven until observed working.

**MVP1 scope note.** Push sits in the master prompt's NOTIFICATIONS section and tech stack but **not** in its 10 SUCCESS CRITERIA (which are the hazard/incident/investigation/CAPA/inspection/dashboard lifecycle). This is therefore a requirement-level gap, materially narrower than the §10 navigability correction. iOS is **out of MVP1 scope** entirely — there is no `ios/` directory, and `docs/18` defers Apple until a macOS runner and signing certs exist.

## 12. Push Delivery — Client Wiring & Recipient Routing (2026-08-15)

Continuing §11 on-device against the live backend. §11 fixed the *transport*; testing then exposed three further defects, all of the same shape as §10 — correct code with no caller, or aimed at a target that did not exist.

**D-push-1 — `registerForPush` was never called.** `NotificationController.registerForPush` (`notification_providers.dart`) carried the docstring "Called after login" and had **zero callers** in `lib/` or `test/`. So `FcmService.init()` never ran, `getToken()` was never requested, `registerDeviceToken` was never reached, and `device_tokens` stayed **permanently empty** — on every build ever produced. `notify-fanout` dutifully queried the table, found nothing, looped zero times and returned `{ok:true, pushed:0}`. No error surfaced at any layer. The same gap killed deep links, since `onDeepLink` is only supplied by that method.
- **Fix:** `OhsShieldApp` (`lib/app.dart`) becomes a `ConsumerStatefulWidget` and registers post-frame once `currentUserProvider` yields a user, guarded by the registered user id so repeat builds no-op and a different user signing in on the same device re-registers. It cannot join the launch-time `ref.watch` calls beside the sync engine (§9): `registerForPush` no-ops without a user, and `device_tokens` RLS requires `user_id = auth.uid()` + matching company, so an anonymous write is rejected at the DB.

**D-push-2 — `capa.assigned` misrouted to the wrong people.** CAPAs are created into the **offline outbox** with a client-minted UUID (`capa_repository_impl.dart`), so the row does not exist server-side when `fire()` runs microseconds later. `notify-fanout`'s `owner_id` lookup missed, `recipients` stayed empty, and control **fell through to the default Safety Officer+ audience** — so the assigned owner got nothing and Safety Officers got "CAPA assigned to you" for other people's CAPAs. Rank was a red herring; an Employee and a Manager owner failed identically.
- **Fix:** the call site passes `data: {'recipientIds': [ownerId]}`. `fire()` spreads it top-level and the function honours `recipientIds` **ahead of any lookup**, removing the race rather than narrowing it — correct online, offline, or mid-sync. No server change.

**D-push-3 — reassignment notified nobody.** `fire()` existed only in `CapaController.create`. The owner picker (`capa_detail_screen.dart`) reassigns via `patch(capa, {'owner_id': …})`, which fired nothing. **Fix:** `patch` now fires `capa.assigned` with explicit `recipientIds` when `owner_id` is present *and changed* — the inequality guard matters because `patch` also serves due-date edits.

**Toolchain.** Flutter upgraded 3.41.6 → **3.44.6 / Dart 3.12.2** on this workstation, matching the recorded target. This fixed a Gradle failure (AGP 9.0.1 new-DSL + unresolved `kotlin { compilerOptions }`) that was **proven pre-existing by a control build** with the Firebase plugin reverted — it was environment skew, not a Firebase regression. The switch left a stale `ink_sparkle.frag` (engine expected format v2, found v1) which failed the suite's one widget test; `flutter clean` resolved it. **Lesson: re-run the full suite after a toolchain change, not just analyze** — 117 of 118 tests are pure Dart and never touch the shader, so the breakage was invisible to analyze and to codegen.

**Verified on-device (2026-08-15).**
- `device_tokens` populates for real users — which also proves Firebase initialises with the live config, FCM issues tokens, the RLS write passes, **and the test tablet has Google Play services** (an open worry, as it is a Unisoc device).
- **In-app notifications are confirmed working end to end**: `fire()` → invoke → JWT auth → role-based recipient resolution → `notifications` insert → RLS read-back → Notification Center.
- **Push delivery is CONFIRMED.** A `capa.assigned` push raised a system notification on the assigned owner's device: `notify-fanout` → service-account OAuth2 → FCM HTTP v1 → Google → handset. **This closes the delivery-boundary item §11 opened** — the transport is proven, not merely deployed. Also the first end-to-end validation of the explicit-`recipientIds` fix (D-push-2), since that push reached the *owner* rather than the Safety Officer audience.

**D-push-4 — CAPA action by a non-creating device threw "Unexpected error".** An assigned owner opening someone else's CAPA and tapping **Start work** got `Could not load: UnknownFailure`. Mechanism: the hazard repo does cache-on-read (§9) but the **CAPA repo never wrote the cache at all** — it only read it. So a device that had not *created* the CAPA held no cached copy; `OfflineMutationService.enqueueUpdate` merges `{...?existing, ...changedFields}`, and with `existing` null it cached the fragment `{"status":"in_progress"}` as `pending`. `get()` then preferred that pending entry (the §10 read-after-write rule) and `CapaDto.fromJson` threw on the missing required fields, landing in `guardAsync`'s catch-all. **The §10 fix was correct but assumed a complete cached row** — true on the creating device, false on every other one, i.e. the normal case for an assigned owner.
- **Fix:** cache-on-read in `CapaRepositoryImpl.list()` and `get()`, mirroring the hazard repository, so `enqueueUpdate` always has a full record to merge over; plus a guarded parse so a partial or stale cache entry falls back to the server instead of hard-failing the screen. Side benefit: CAPA list/detail now survive going offline on a device that only ever read them.
- **Diagnostic note:** the true cause was masked twice — the inner `catch` logs any server failure as "server unavailable, using cache", and the subsequent miss surfaced as a bare `StateError`. Worth remembering that `UnknownFailure` means *"an exception guardAsync does not map"*, i.e. never RLS, network, auth or Postgrest.

**Foreground notifications — implemented (Option A).** Android does not display a notification while the app is in focus; it delivers to `onMessage`, and there was no handler, so a push arriving during use was silently dropped. `FcmService.init()` now takes an optional `onForegroundMessage`; `app.dart` holds a `GlobalKey<ScaffoldMessengerState>` and raises an in-app SnackBar (title, body, **View** action deep-linking via the same `router.go` path as a tap). The entity→route map was extracted to `_routeFor(RemoteMessage)` and is now shared by the banner and both tap handlers. `registerForPush` also invalidates `notificationsListProvider` so the unread badge refreshes without opening the Center.
- **Deliberately an in-app banner, not a system notification.** Background/terminated delivery already works via FCM auto-display; this fills only the in-focus gap. A true foreground heads-up would need `flutter_local_notifications`, a declared Android notification channel (the app declares none — which is why `fcm.ts` sends no `channel_id`), and a monochrome notification icon. Scoped as MVP2 polish.

**Known gaps, unfixed and deliberate.**
- **`capa.overdue` and `inspection.due` have no caller.** Defined in `NotificationTrigger`, fully supported server-side, but nothing dispatches them; the scheduled sweep remains the deferred cron Edge Function (DEV). Live triggers are `hazard.created`, `incident.created`, `risk.assessed`, `capa.assigned`, `investigation.due`.
- **`hazard.created` deep links can 404 briefly** — hazards also create through the outbox, so the target may not exist server-side when the notification lands. Delivery is unaffected (recipients come from the role query, not an entity lookup).

**Process.** Five defects in one day. Four were the §10 shape — correct code with a missing caller, call site or target (`registerForPush`, `capa.assigned` routing, reassignment, the retired FCM endpoint). The fifth (D-push-4) is a variant worth naming separately: **correct code resting on an assumption that held only where it was first tested.** The §10 read-after-write rule was right for the device that created a record and wrong everywhere else, and it shipped because testing had only ever exercised the creating device.

The rule stands, restated: **a feature is done when its effect is observed, not when its code exists** — and observed *on a device that did not originate the data*, since single-device testing hides exactly this class of bug. Every failure here was silent, because each layer treated "nothing to do" as success.

## 13. Scheduled Sweep & Timezone Correction (2026-08-15)

### 13.1 `notify-sweep` — the deferred cron, delivered

`capa.overdue` and `inspection.due` were defined in `NotificationTrigger` and fully supported by `notify-fanout`, but **nothing could ever raise them**: they describe conditions that become true with the passage of time, not user actions, and Prompt 15 left the sweep as a deferred cron (DEV). New Edge Function `notify-sweep` + migration **0017** close it.

- **What it sweeps.** Overdue CAPAs (`due_date < today`, status ≠ closed, owner set) — `<` not `<=`, so overdue starts the day *after* the due date, matching §10. Due inspections (`scheduled_date <= today`, status in draft/in_progress; submitted/closed need no chasing).
- **Recipients — owner only (decision).** The CAPA owner; the assigned `inspector_id` for inspections. A CAPA with no owner has nobody to chase and is skipped (it still shows on the dashboard overdue KPI). Escalation to Safety Officers after N days was considered and **rejected for MVP1** as noisy — one notification per overdue CAPA per SO per day. Revisit with an agreed threshold.
- **Idempotency — at most one notification per entity per trigger per calendar day**, enforced by checking `notifications` for rows created since midnight. Without this a daily sweep re-notifies the same overdue CAPA forever. Chosen over a `last_notified_at` column so no schema change is needed; the notifications table is already the record of what was sent.
- **Auth — `verify_jwt = false` + a shared secret.** pg_cron has no user session, so the §9 rule ("all functions verify_jwt=true, app-invoked with the user JWT") does not apply to this caller. Deployed with `--no-verify-jwt` and gated on `SWEEP_SECRET`; it runs as service role, so **the secret is the only gate** and the function fails closed (403) until it is set.
- **`fcm.ts` moved to `supabase/functions/_shared/`** so the event-driven and scheduled functions share one transport. `notify-fanout` redeployed (v4) — identical code, relocated only.

**D-cron-1 — `alter database ... set` is not available on hosted Supabase.** The first cut stored the function URL and secret as custom database parameters, read via `current_setting()`. Applying it failed with `42501: permission denied to set parameter` — the hosted `postgres` role is not superuser. **Fix:** both live in **Supabase Vault** (`vault.create_secret` / `vault.decrypted_secrets`), read by the `SECURITY DEFINER` function. This also keeps migration 0017 environment-agnostic and secret-free, which matters because dev/uat/prod are separate projects with different URLs and secrets.

**Migration tracking drift — found and repaired (2026-08-15).** `supabase migration list` reported **all** migrations as unapplied remotely: §9 bootstrapped the schema by hand via `apply_all.sql`, which does not write `supabase_migrations.schema_migrations`. This was not cosmetic — `.github/workflows/ci.yml` runs `supabase db push` on every `v*` tag, so **the first tagged release would have tried to replay 0001→0017 against a fully populated database** and failed the deploy. Repaired with `supabase migration repair --status applied 0001…0017`, which writes the tracking table without executing SQL; `migration list` now shows local == remote for all 17, and `db push` is safe.

**D-env-1 (convention).** `apply_all.sql` is a **dev-bootstrap convenience only**. uat/prod must be created by `supabase db push` applying migrations from scratch, never by the combined file — otherwise each new environment reintroduces this drift. Dev was the only project affected (uat/prod do not exist yet), so nothing else needed repair.

**CI gap — `notify-sweep` was not in the deploy list.** `ci.yml` deployed four functions; a tagged release would therefore have applied migration 0017 (which *schedules* the sweep) without deploying the function it calls. It also needs `--no-verify-jwt`, so it cannot be appended to the existing command and now has its own step. Same shape as the rest of this session: a piece that exists but is not wired into the path that runs it.

### 13.2 D-tz-1 — every absolute timestamp rendered N hours behind

Reported as notifications showing 2 hours behind in CAT (UTC+2). Systemic, not notification-specific: Postgres `timestamptz` serialises with an offset, so `DateTime.parse` yields a **UTC** `DateTime`, and `DateFormat.format()` prints that value's own wall-clock — i.e. UTC. Every user east of UTC saw absolute times shifted back by their offset. `toLocal()` existed in exactly two places in the codebase, one of them `priority_item.dart`, where the symptom had evidently been hit and patched locally without the general cause being found.

- **Fix:** `lib/core/utils/date_time_x.dart` — `DateTime.local` (`isUtc ? toLocal() : this`), applied at all seven absolute-timestamp display sites (Notification Center, audit list/detail, incident list/detail, report history, PDF export).
- **The `isUtc` guard is load-bearing.** `date` columns (`due_date`, `scheduled_date`) parse as **local midnight**, not UTC. A blanket `toLocal()` is harmless east of UTC but shifts the day *west* of it. Guarding leaves date-only values untouched.
- **Relative times were never wrong.** `friendlyTimeAgo` works on `difference()`, which compares absolute instants regardless of `isUtc`.
- Covered by `test/core/utils/date_time_x_test.dart` (UTC converts and stays the same instant; date-only untouched; idempotent).
- **Residual, documented:** `notify-sweep` computes "today" as a UTC date. At its 06:00 UTC / 08:00 CAT run time the UTC and local dates agree, so scheduled runs are correct; a *manual* run between 00:00–02:00 CAT would use the previous UTC day.

**Process.** D-tz-1 is a third failure shape, distinct from the §12 pair: **a correct local patch that masked a general defect.** Someone fixed the dashboard's timestamps with a `toLocal()` at the point of pain and moved on, leaving six other surfaces wrong and no shared helper. Worth asking, when a fix is a one-liner at a call site: *is this the only place this data crosses this boundary?*

## 14. Device Verification & Workstation Fixes (2026-08-16)

First session with a working `flutter run` on the tablet (TARGA F8, Android 15 / API 35), so the §12–§13 items that were "implemented but unverified on device" could finally be observed rather than inferred.

**W-adb-1 — `adb` hung indefinitely on this workstation; fixed with `ADB_LIBUSB=0`.** `adb version` returned instantly but `adb devices` never returned, on both the SDK's 37.0.0 and a freshly downloaded 37.0.1, with and without a device attached. **The initial diagnosis (loopback TCP being filtered) was wrong** and was disproved by measurement: loopback listen+connect+accept completes in 5 ms, and a connect to the closed port 5037 returns a correct `ConnectionRefused`. The real cause is adb's **libusb backend hanging during USB enumeration at server startup** — which explains why the binary ran fine, why alternate ports made no difference, why `nodaemon server` printed nothing, and why it hung with no Android device present (it was enumerating the webcam/hub/card-reader). `ADB_LIBUSB=0` selects the legacy Windows USB backend; set at User scope, so new shells inherit it. Note this is a **workstation** fix, not a repo change.

**D-ui-1 — incident trend chart overflowed by 4.0 px.** `MiniBarChart` sized its bars as `height - 34`, reserving 34 px for chrome that actually measures **38** — two 12 pt `labelSmall` lines at ~16 px plus the 2 px and 4 px gaps. Fixed by removing the constant rather than correcting it: the bar is now an `Expanded` inside the column with `FractionallySizedBox(heightFactor:)`, so it takes whatever remains after the labels and cannot exceed its parent. This also survives a type-scale change or a user's larger font setting, where the magic number would have overflowed far worse than 4 px.

**Verified on device (all previously open).**
- **Foreground banner** — reporting a hazard raised the in-app banner ("New hazard reported" + body + **View**) over the hazard list. Proves the whole chain in one action: `fire()` → `notify-fanout` → recipient resolution → service-account OAuth2 → FCM HTTP v1 → Google → device → `onMessage` → banner.
- **Timestamps in device timezone** — the Notification Center shows the sweep's `capa_overdue` entry at **Aug 16 8:00 AM**. The cron is `0 6 * * *` **UTC** and CAT is UTC+2, so 8:00 AM is the correct rendering and 6:00 AM would have been the old bug. Confirmed against a timestamp whose true value is independently known.
- **CAPA "Start work"** — transitions to In Progress with a confirmation toast; no `UnknownFailure` (D-push-4 closed).
- **Chart** — no overflow stripe, all six week labels visible, bar correctly proportioned.

**The scheduled sweep ran unattended.** That `Aug 16 8:00 AM` notification was raised by **pg_cron at 06:00 UTC with nobody involved** — the first proof the scheduler works in production rather than only when invoked by hand. Body format matches `notify-sweep` (`Due <date>: <description>`) with the `high` badge, and the idempotency guard held: one entry for that CAPA today, not repeats.

**Process — verify the artefact under test is the artefact you think it is.** The first screenshot after `flutter run` still showed the 4 px overflow, and the near-conclusion was "the fix does not work". It was yesterday's build: `dumpsys package … lastUpdateTime` read `2026-08-15 13:23:53` while Gradle was still assembling. Checking install time before interpreting the screen would have avoided it. A sibling of the §12 lesson: there, code was assumed to run because it existed; here, a build was assumed deployed because a command had been issued.

## 15. RBAC Affordances, Workflow Clarity & Assignment Fixes (2026-08-16)

A round of UX work driven by on-device use, plus two defects it exposed.

### 15.1 Client-side RBAC affordances

Architecture §10 mandates two layers: RLS (authoritative) + conditional UI (UX only). The second layer existed on **hazard and incident only**; CAPA, investigation, inspection and user-admin showed every action to every role and let the server reject it — so a Supervisor could tap "Verify & close" and receive an error instead of seeing it was not theirs to press.

- **`lib/shared/widgets/rank_gated_action.dart`** — `hasMinRank()`, `RoleDeniedNote`, and `RankGatedAction` (full-width action, disabled with the reason beneath). `onPressed` is nullable and the rank check **only ever disables further**, so a caller's own busy/incomplete logic composes safely. `permitted` overrides the rank comparison for guards that are not purely rank-based.
- Applied to CAPA, investigation and inspection; **hazard and incident refactored onto it** — they had already diverged, one using an inline `TextStyle(fontSize: 11)` and the other `theme.labelSmall`.
- **Investigation folds the rank check into `canEdit`**, so the analysis fields are read-only for lower ranks, not just the buttons — otherwise a user can write a full root-cause analysis and only be refused at save.
- **User & Access Administration deliberately not gated**: the router already restricts `/admin` to rank 5, so per-button gating would be redundant styling churn. Noted that the guard reads `rank != null && rank < 5`, so a null rank passes — better fixed at the guard than papered over per button.
- **Still UX only.** Every gate mirrors an existing server-side rule. A gate stricter than its policy silently blocks legitimate work; a gate looser than its policy is invisible until someone hits an error.

### 15.2 D-capa-1 — assigning an owner left the CAPA in Created, stranding the assignee

Reported as: the assignee receives the notification, opens the CAPA, and finds a greyed-out **Assign** button and no way to Start work.

`_assignOwner` patched **only** `owner_id`. The create path sets both (`status: ownerId != null ? assigned : created`), but the picker path never moved the status. A Created CAPA therefore gained an owner while staying Created, so its next step was *Assigned* — a Supervisor-rank action — which an Employee owner cannot perform. **Start work only exists from Assigned, so it was unreachable.** Fixed: assigning an owner to a Created CAPA now writes the status in the same patch.

**The §15.1 gating did not cause this — it exposed it.** Before, the button was enabled, the tap was rejected server-side, and the CAPA stayed stuck anyway. The gate turned a silent dead end into a visible one. Worth remembering when adding affordances to existing flows: a newly-greyed control often means the underlying path was already broken.

### 15.3 Confirm-before-commit on selection dialogs

Reported as: choosing a name in the picker assigned it immediately. Both offenders used `SimpleDialog` + `SimpleDialogOption`, which pops on tap — so touching a name *was* agreeing to it, and a mis-tap wrote a change (and fired a notification) with no chance to reconsider.

A sweep found **exactly two** such dialogs — CAPA "Assign owner" and incident "Link to hazard". The other eleven already had Cancel + confirm. Replaced with `lib/shared/widgets/select_one_dialog.dart`: tap selects, the confirm button commits and stays disabled until something is chosen. The current value is pre-selected, and an unchanged selection is a no-op rather than a spurious reassignment + notification.

### 15.4 Workflow legibility

Reported as: "does Start work mean the work is finished?" — because the button names the *next* action, so tapping "Start work" and immediately seeing "Submit for verification" reads as a skipped step.

- **Status / Next lines** above the action on CAPA, incident and investigation (hazard already had "Next step").
- **`lib/shared/widgets/status_stepper.dart`** on all five workflow screens. Takes `labels` + `currentIndex`, so **no status enum needed changing** — hazard's `step` was only ever `values.indexOf(this)`. Hazard's private `_StatusStepper` was deleted and refactored onto it. Documented as assuming a **single linear path**: true of all five MVP1 workflows, but it would become actively misleading rather than merely incomplete if one gained a branch or rejection route.
- **Assignee names** (`lib/core/utils/user_lookup.dart`): CAPA and investigation read `Assigned: <name>`. **Incidents show "Reported by" instead** — they have no assignee column, only `reporter_id`; labelling that as an assignment would assert an ownership the record does not carry. Incident work is owned through its linked investigation and CAPAs, which do have owners. Giving incidents a real assignee is a schema change, not a wording change.
- **CAPA detail gained pull-to-refresh** (hazard already had it). A CAPA opened from a notification can be read before the assigning device's outbox has synced, and a `FutureProvider` does not re-fetch on its own.

### 15.5 D-ui-2 — notifications showed a white blob instead of the app icon

Android flattens the notification small icon to its **alpha channel** (API 21+), and with none declared, FCM falls back to the launcher icon — a full-colour squircle that is opaque edge to edge, so it flattens to a solid square.

Added `android/app/src/main/res/drawable/ic_stat_ohs_shield.xml` (vector, so no per-density PNGs) and declared it via `com.google.firebase.messaging.default_notification_icon`, with `@color/brandGreen` as the accent. Geometry is the shield + cross from the branding SVG, scaled to the 24dp viewport; **the gauge ring and check badge are dropped** because at 24dp they collapse into noise. The cross is a **hole** (`evenOdd`), expressed as one plus-shaped subpath rather than two overlapping bars — under `evenOdd` the intersection of two rects flips back to filled and would put a solid square in the middle.

Affects background/terminated notifications only; the foreground path is the in-app banner, which has no icon. `fcm.ts` still deliberately sends no `channel_id` — the app declares no channel.

## 16. Self-Notification & Reporter Attribution (2026-08-16)

**D-notif-1 — users were notified about their own actions.** Reported as: logging a hazard produced an in-app notification for the person who logged it. Correct by the rule, wrong as behaviour — `hazard.created`, `incident.created`, `risk.assessed` and `investigation.due` fan out to Safety Officer+ (§Notifications), so any SO/Manager/Admin reporting something was in their own audience.

**Fix:** `notify-fanout` filters `callerId` out of `recipients`. Two placement points matter:
- **After** recipient resolution but **before** the empty-list check, so removing the actor can never fall through to the default Safety Officer+ audience — the wrong order would have escalated a self-notification into a company-wide one.
- It also covers **self-assignment**: a CAPA you assign to yourself is already in your Actions list.

Suppresses only the notification. Audit rows, workflow state and other recipients are unaffected — a hazard you report still reaches your colleagues. Deployed (no app release required).

**Reporter attribution.** The hazard list showed `category · status` with no indication of who raised it; the reporter was only discoverable by opening the record. Now appends the reporter's name via `nameForUser`, **omitted rather than blank** when the roster has not loaded or the reporter is outside RLS-visible scope. Capped to one line with ellipsis — three segments plus a full name overflows a phone width.

**D-lang-1 (toolchain note).** The list change was first written with null-aware collection elements (`?expr`), which the installed Dart 3.12 accepts. It would not have compiled: a package's **language version comes from the pubspec SDK floor** (`>=3.5.0`), not the installed SDK, and `?expr` requires 3.9+. Worth remembering before reaching for a recent language feature — the analyzer catches it, but the reflex "the SDK supports it" is wrong here. Rewritten with collection-`if`.

## 17. CAPA Completion Notes & the Owner's Doing Phase (2026-08-16)

Asked for: let people record what they did when finishing assigned work, and surface it in reports. Investigating it exposed a workflow gap that had to be settled first.

**The blocker — the owner could not finish their own work.** `Submit for verification` moves a CAPA to *Verification*, gated at Safety Officer+ in both layers (`CapaWorkflow.minRankFor`, and the `capa_update` WITH CHECK from 0016). An Employee owner could **Start work** (§10) but not hand it back: someone senior had to submit on their behalf, so there was no transition of theirs to attach completion notes to. Adding a notes field without fixing this would have produced a field its intended author could never reach.

**D-workflow-1 — the owner's doing phase (migration 0018).** The owner may now run their own CAPA through *Assigned → In Progress* **and** *In Progress → Verification*. **Closing remains Safety Officer+**, so an owner may hand work back but never accept it — the separation of duties that matters is untouched. Enforced in three places that must agree: the RLS `WITH CHECK` (authoritative), `CapaWorkflow.canTransition`, and the client affordance.

**`completion_notes`, deliberately not `verification_notes`.** The existing column is the *verifier's* rationale for accepting the work; the new one is the *doer's* account of performing it. Reusing the existing field needed no migration and was rejected: collapsing them leaves an audit record where it is impossible to tell who wrote which, and a CAPA's evidence trail is precisely what a regulator reads. Also considered and deferred: a general `record_comments` thread (~2 days, and reports would have to flatten a conversation into a cell). A column does not block adding threads later.

**Prompt behaviour.** Submitting opens a "What was done?" dialog. **Cancel abandons the transition; an empty note still submits.** Requiring text would teach people to type "done" to get past it — worse than an honest blank, because it looks like a record.

**Reporting.** The CAPA status report gains a *Work completed* column. CSV and PDF needed no changes: both are driven by the `columns` list the repository returns.

**A test caught the policy change.** `capa_workflow_test.dart` asserted *"owner exception does not extend past In Progress"* — exactly the rule being moved — and failed. Split into two rather than flipped: one covering the new allowance (and that a **non-owner** of the same rank still cannot), one asserting the owner can **never** close even with verification evidence present. The original test was really guarding separation of duties; only its boundary moved, so deleting it and keeping the happy path would have dropped the guard that stops an owner signing off their own work. **When a deliberate change breaks a test, ask what principle it was protecting before rewriting it — the principle usually survives the change.**

**Applied via `supabase db push`** — the first real use since §13's `migration repair`, and the proof it worked: the dry run listed only 0018 rather than trying to replay 0001 onward.

## 18. `capa.verification_due` — the Missing Handover Signal (2026-08-16)

Submitting a CAPA for verification told nobody. §17/0018 let the owner hand work back themselves, which made the gap sharper: the action moved to *Verification* and sat there until a Safety Officer happened to look at the board. It was the **only step in the CAPA lifecycle with no signal to the people who must act on it** — hazard/incident creation, risk assessment, assignment and overdue all notify; the handover did not.

**🔖 Deviation from D7 — an eighth trigger.** The canonical list (§3) was fixed at seven names in Prompt 1. `capa.verification_due` is added deliberately, recorded here rather than quietly extending a locked set. Migration **0019** adds the matching `notification_trigger` enum value.

**Naming.** `capa.verification_due`, not `capa.submitted`. The existing convention — `investigation.due`, `inspection.due` — names the **obligation created**, not the event that occurred. A Safety Officer cares that something needs verifying, not that a button was pressed. Keeping the convention means the enum still reads as a list of things owed rather than a mixed log.

**Recipients need no branch.** It falls through to the default Safety Officer+ audience, which is exactly the right set. §16's actor filter composes with it for free: a Safety Officer who owns *and* submits their own CAPA is not notified about their own submission. Two independent rules meeting correctly without a special case is worth noting — the alternative would have been a `capa.assigned`-style explicit recipient list.

**Not subject to the §12 outbox race.** `capa.assigned` needed explicit `recipientIds` because the server had to read the CAPA row to find the owner, and that row may not have synced yet. Here the audience comes from a role query against `user_roles`, which is independent of the CAPA — so firing immediately after the local patch is safe.

**Postgres note.** `ALTER TYPE ... ADD VALUE` is permitted inside a transaction on PG 12+ provided the new value is not *used* in the same transaction. The migration only adds it; first use is a later INSERT from the Edge Function.

## 19. CI Has Never Passed — Toolchain Pin Corrected (2026-08-16)

First push to `origin` this session triggered CI. It failed. So did **run #1 on `eadddf3`**, the baseline import from 2026-08-14, at the **same step** — `flutter pub get`. **CI has never passed on this repository.** It was authored at Prompt 18 and, on the evidence, never run green; "CI exists" was true, "CI is green" was never established.

Both `Build` and `Deploy Supabase` were *skipped*, not failed — they `needs:` the two failing jobs. Which means the more serious consequence is not the red badge: **no release could ever be cut through CI**, because a `v*` tag cannot reach the AAB build or the migration deploy while those jobs fail. A go-live blocker, sitting dormant since Prompt 18.

**🔖 Deviation — `FLUTTER_VERSION` 3.24.5 → 3.44.6.** The Master Prompt pins 3.24.5. The Android config now requires AGP 9.0.1's new DSL, which older Flutter does not supply — proven by a control build on 3.41.6 (§14, W-adb-1 round) that failed at Gradle script compilation before touching app code. **CI was therefore testing a configuration this codebase cannot compile in.** Aligning the pin to the version the app is actually built, tested and device-verified on makes CI reproduce reality rather than an aspiration.

**`supabase/setup-cli` pinned to 2.114.0** (was `version: latest`). Run #2 died *inside the action itself*, and run #1 at `supabase start` — different steps, which is the signature of an unpinned dependency moving underneath you. An unpinned tool makes a job fail for reasons unrelated to the change under test, which is the opposite of what CI is for.

**Confirmed by run #3.** The version pin was the cause: `flutter pub get` and `build_runner` both pass on 3.44.6, having failed at the first step on 3.24.5. The failure moved two steps forward, to `flutter analyze`.

**D-verify-1 — "analyze is clean" was never measured.** Every green analyze reported during this session came from a shell pipeline (`flutter analyze | tail`), whose `$?` is the **exit status of `tail`**, not of analyze. Run without a pipe, `flutter analyze` exited **1** on the nine deprecation infos, and had done all along. CI was right and the local reporting was wrong — a good argument for treating CI as the source of truth rather than a local shell. **When an exit code is the thing being asserted, do not pipe the command.**

The nine were all genuine deprecations, now fixed (analyze: *No issues found*, exit 0):
- **`RadioListTile` per-tile `groupValue`/`onChanged`** ×6 → a `RadioGroup` ancestor (in `widgets/`, re-exported by `material.dart`).
- **`Supabase.anonKey`** → `publishableKey`. A rename; the value passed was already a publishable key, so the old parameter name was the misleading part.
- **Riverpod `provider.stream`** ×2 → `connectivityStreamFactoryProvider`. Not a rename, and both obvious replacements are wrong: dropping the initial `checkConnectivity()` leaves consumers with **no value until connectivity changes** (sync engine idles, offline banner blank on a healthy connection), and `asBroadcastStream()` delivers that initial state only to whichever consumer subscribes first, leaving the other silently blind. An `async*` stream is single-subscription, so a cached instance would throw on the second listener. A **factory** — one fresh stream per consumer — is the only shape that works; documented at the provider so neither dead end gets retried.

**Related, unfixed.** `pubspec.lock` is gitignored, so CI resolves dependencies fresh and has never validated the exact set running locally. Committing the lockfile would make CI reproduce the verified environment rather than approximate it — worth considering, and a larger decision than a version bump.

**Still untested anywhere: the release build.** Every build this session has been `--debug`. `flutter build appbundle --release --flavor prod` has never run on any toolchain. Release differs in tree-shaking, R8/ProGuard and signing, and R8 has a history of breaking reflection-based plugins — Firebase Messaging being exactly that shape, and already emitting Kotlin-migration warnings. This is the highest-value untested path before go-live, independent of the CI question.

## 7. Open Questions / Deviations Log
- **OQ1:** Confirm `companies` table addition (D1) at Prompt 2A.
- **OQ2:** Confirm typed-FK linkage vs. untyped polymorphic (D2) at Prompt 2A.
- **DEV1:** Supabase Realtime not used in MVP1 (read-models designed to allow it later without redesign).
- **DEV2:** JWT-claims access-token hook deferred in favour of `SECURITY DEFINER` helpers (D3).
- **D9 (deviation):** Incident witnesses/injured-party stored as POPIA-minimal JSONB on `incidents` (not a separate `incident_witnesses` table), to keep the mandated table set intact; visibility governed by the incident row's RLS. Revisit if per-field erasure/audit granularity is later required.
- **DEV3:** On tables lacking `department_id` (`investigations`, `corrective_actions`), supervisor SELECT scope falls back to **site** (not department). Documented in docs/02b.

---

**Governance note:** Section 2 values are copied from MVP1_1.md for convenience — restated, not editable here. If any must change, change MVP1_1.md and re-derive; never let the Ledger and Master Prompt diverge.
