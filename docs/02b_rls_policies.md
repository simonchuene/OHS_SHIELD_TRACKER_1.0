# OHS Shield Tracker — MVP 1 Row Level Security & Policies (Prompt 2B)

> Builds on the approved Prompt 2A schema. Source of truth: `MVP1_1.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval.

## SQL artifacts (apply after 0005)

| File | Contents |
|---|---|
| [0006_rls_helpers.sql](../supabase/migrations/0006_rls_helpers.sql) | `app.*` SECURITY DEFINER scope/role helpers (D3) |
| [0007_rls_policies.sql](../supabase/migrations/0007_rls_policies.sql) | RLS enabled on all 20 tables + per-action policies |
| [0008_storage_policies.sql](../supabase/migrations/0008_storage_policies.sql) | attachments bucket + storage.objects policies |

## 1. Scoping model

- **Claim source (D3):** scope is read from `user_profiles`/`user_roles` via `SECURITY DEFINER` helpers — `app.current_company_id()`, `app.current_site_id()`, `app.current_department_id()`, `app.user_rank()`, `app.has_min_rank(n)`. DEFINER bypasses RLS on those tables (avoids recursion) and always reflects current data (no stale JWT claims).
- **Rank ladder:** employee=1 · supervisor=2 · safety_officer=3 · manager=4 · administrator=5.
- **Tenant isolation:** every policy is gated by `company_id = app.current_company_id()` first. Cross-company access is impossible regardless of role.
- **Visibility ladder (SELECT):** own (rank 1) → department (rank 2) → site (rank 3) → enterprise (rank 4–5), matching the Master Prompt's View Own/Department/Site/Enterprise rows. Tables without a `department_id` (investigations, corrective_actions) scope supervisors to **site** (documented deviation DEV3).
- **Deny by default:** RLS is enabled on all 20 tables; any operation without a matching policy is rejected.
- **Service-role boundary:** server-side inserts (notifications, audit_logs, cross-record fan-out) run under the service-role key inside Edge Functions/triggers, which **bypass RLS**. The service-role key never ships in the app.

## 2. RLS enabled on every table (explicit)

companies · sites · departments · users · roles · user_roles · user_profiles · hazards · risk_assessments · incidents · investigations · corrective_actions · inspections · inspection_items · notifications · device_tokens · attachments · attachment_versions · audit_logs · sync_queue — **20/20 enabled** ([0007 §1](../supabase/migrations/0007_rls_policies.sql)).

---

## 3. Self-Check A — Master Prompt RBAC matrix → enforcing policy

Legend: ✅ allowed, ❌ denied by policy predicate. Every cell is enforced by the named policy's `USING`/`WITH CHECK` via `app.has_min_rank()` / scope helpers.

| Action (Master Prompt) | Emp(1) | Sup(2) | SO(3) | Mgr(4) | Admin(5) | Enforcing policy |
|---|:--:|:--:|:--:|:--:|:--:|---|
| Report Hazard / Incident | ✅ | ✅ | ✅ | ✅ | ✅ | `hazards_insert`, `incidents_insert` (rank≥1, reporter=self) |
| Perform Risk Assessment | ❌ | ✅ | ✅ | ✅ | ✅ | `risk_insert`/`risk_update` (rank≥2) |
| Conduct Investigation | ❌ | ✅ | ✅ | ✅ | ✅ | `invest_insert`/`invest_update` (rank≥2) |
| Create / Assign CAPA | ❌ | ✅ | ✅ | ✅ | ✅ | `capa_insert`/`capa_update` (rank≥2) |
| Verify & Close CAPA | ❌ | ❌ | ✅ | ✅ | ✅ | `capa_update` WITH CHECK (`status∈{verification,closed}` ⇒ rank≥3) |
| Close Hazard / Incident | ❌ | ❌ | ✅ | ✅ | ✅ | `hazards_update`/`incidents_update` WITH CHECK (`status='closed'` ⇒ rank≥3) |
| Conduct Inspections | ❌ | ✅ | ✅ | ✅ | ✅ | `inspections_insert`/`_update`, `insp_items_write` (rank≥2) |
| View Own Records | ✅ | ✅ | ✅ | ✅ | ✅ | `*_select` own-clause (`reporter_id/owner_id/…=auth.uid()`) |
| View Department Records | ❌ | ✅ | ✅ | ✅ | ✅ | `*_select` (rank=2 ⇒ `department_id=current_department`) |
| View Site / Enterprise Dashboards | ❌ | ❌ | ✅ | ✅ | ✅ | `*_select` (rank=3 site; rank≥4 enterprise) + dashboard read models |
| Manage Users & Roles | ❌ | ❌ | ❌ | ❌ | ✅ | `user_roles_admin_manage` (rank≥5) |
| View Audit Log | ❌ | ❌ | ✅ | ✅ | ✅ | `audit_select` (rank≥3) |

**Result:** 12/12 actions mapped; all 5 roles represented; every allow/deny cell traces to a concrete predicate. No action is unmapped and no unintended grant exists (deny-by-default + explicit thresholds).

## 4. Self-Check B — per-table CRUD posture

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| roles | all auth | ❌ | ❌ | ❌ |
| companies / sites / departments | company | admin | admin | admin |
| users | company | ❌ (trigger) | ❌ (trigger) | ❌ |
| user_profiles | company | self/admin | self/admin | ❌ |
| user_roles | company | admin | admin | admin |
| hazards / incidents | own→dept→site→ent | rank≥1 (self) | rank≥2 (close⇒≥3) | ❌ |
| risk_assessments | rank≥2 / own hazard | rank≥2 | rank≥2 | ❌ |
| investigations | rank≥2 site / own | rank≥2 | rank≥2 | ❌ |
| corrective_actions | rank≥2 site / owner | rank≥2 | rank≥2 (verify/close⇒≥3) | ❌ |
| inspections / inspection_items | own→dept→site→ent | rank≥2 | rank≥2 | ❌ |
| notifications | recipient | ❌ (service) | recipient (read-state) | ❌ |
| device_tokens | self | self | self | self |
| attachments | company | rank≥1 | creator/SO+ | ❌ (soft-delete) |
| attachment_versions | company | rank≥1 | rank≥1 | ❌ (history kept) |
| **audit_logs** | **rank≥3** | **❌** | **❌** | **❌** |
| sync_queue | self | self | self | self |

## 5. Self-Check C — audit_logs has no mutation path ✅

1. **No policy** grants INSERT/UPDATE/DELETE to `authenticated` (only `audit_select`).
2. **Grants revoked:** `revoke insert, update, delete on public.audit_logs from authenticated, anon;` — defence in depth ([0007 §12](../supabase/migrations/0007_rls_policies.sql)).
3. **Writes** occur only via SECURITY DEFINER triggers / Edge Functions under the service role (bypass RLS), never from the client.
4. Table has no `updated_at` and is write-once by design (Prompt 2A). POPIA erasure redacts referenced business rows, never audit rows (D6).

⇒ No UPDATE/DELETE path exists for any client role.

## 6. Storage policies (attachments)

- Private bucket `attachments`; access via signed URLs.
- Path convention `<company_id>/<owner_type>/<owner_id>/<version_uuid>.<ext>`; policies assert `foldername[1] = current_company_id()` for tenant isolation.
- **read** any auth in company · **upload** rank≥1 in company · **update** uploader-or-SO+ · **delete (physical)** SO+ only (logical delete stays app-layer; version history never destroyed).

## 7. Decisions captured for the Ledger (pending approval)

| ID | Decision | Slot |
|---|---|---|
| D3 (implemented) | RLS scope via `app.*` SECURITY DEFINER helpers | §5 RLS scoping (confirm) |
| D6 (implemented) | `audit_logs` immutable — no policy + grants revoked | §5 Audit immutability (confirm) |
| DEV3 | Supervisor SELECT scope falls back to **site** on tables lacking `department_id` (investigations, corrective_actions) | §7 Deviations |
| D-rls-1 | Storage tenant isolation via first path segment = `company_id`; physical delete = SO+ | §5 Security |

**End of Prompt 2B deliverable.**
