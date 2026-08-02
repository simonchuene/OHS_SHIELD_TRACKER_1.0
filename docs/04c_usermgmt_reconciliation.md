# OHS Shield Tracker — User Management Schema & RLS Reconciliation (Prompt 4C)

> Delta only — **not** a re-run of 2A/2B. Reconciles the existing `users`/`user_profiles`/`user_roles` schema + RLS with `MVP1_2.md → USER MANAGEMENT & PROVISIONING`. Runs immediately **before Prompt 5 (Auth)** so Auth builds against the final user/role shape.
>
> **Status:** Draft for human approval. Migrations: [0009](../supabase/migrations/0009_user_mgmt_reconciliation.sql) (schema), [0010](../supabase/migrations/0010_user_mgmt_rls.sql) (RLS).

## Context

`MVP1_1.md` (used for 2A/2B) predated the USER MANAGEMENT & PROVISIONING section. The project now adopts **`MVP1_2.md`** as canonical (see Ledger header), which adds the identity model, scope-aware roles, user lifecycle, invite-based provisioning, 4 admin-only RBAC rows, and defers licensing to MVP2.

## 1. Gap Analysis (required vs. existing)

| # | Requirement (MVP1_2.md · USER MGMT) | Existing (Ledger §1/§5, 2A/2B) | Verdict |
|---|---|---|---|
| G1 | 3-layer identity: `auth.users` / `user_profiles` (1:1) / `user_roles` | `users` mirrors auth.users; `user_profiles` 1:1; `user_roles` present | **already present** |
| G2 | `user_profiles` holds company/site/department + POPIA-minimal contact | company_id, site_id, department_id, first/last name, phone, job_title, avatar_path | **already present** |
| G3 | `user_roles` scope-aware: nullable `site_id` **and** `department_id` (NULL=company-wide) | had `site_id` nullable; **no `department_id`** | **migration needed** (0009 §3) |
| G4 | Uniqueness of scope assignments incl. company-wide (NULL scopes) | old `unique(user_id, role_id, company_id, site_id)` — NULLs distinct → dup company-wide rows possible | **migration needed** (0009 §3, `NULLS NOT DISTINCT`) |
| G5 | `user_profiles.status` enum `invited·active·suspended·deactivated` + lifecycle timestamps | only `is_active` boolean | **migration needed** (0009 §1–2) |
| G6 | Never hard-delete a user (retain history) | `user_profiles`/`users` had no DELETE policy; but `user_roles_admin_manage` was `FOR ALL` (**included DELETE**) | **migration needed** (0010) |
| G7 | Provisioning = Administrator-only, no self-registration; privileged ops via service-role Edge Function | 2B allowed `user_profiles` self-insert / self-update | **migration needed** (0010) |
| G8 | Admin-only INSERT/UPDATE on user tables, scoped to admin company | `user_roles` admin-manage present; `user_profiles` writes too permissive | **migration needed** (0010) |
| G9 | Indexes on company/site/department for user tables (RLS) | company indexed on both; `user_roles` site/department not indexed | **migration needed** (0009 §2–3) |
| G10 | Claims derivation still correct with multiple scope-aware role rows | `app.user_rank()` = max rank across rows; home scope from `user_profiles` | **already present** (re-verified §4) |
| G11 | Licensing/seats/billing deferred to MVP2; invite gate extensible | no billing built | **already present** (nothing to build) |
| G12 | Audit every invite/role change/suspend/reactivate/deactivate | `audit_logs` immutable infra exists; writes wired in Prompt 5A | **already present** (infra) |

## 2. Forward migration summary

- **0009** — `user_status` enum; `user_profiles.status` (+ `invited_at`/`activated_at`/`deactivated_at`), backfilled from `is_active` (now deprecated), indexed; `user_roles.department_id` FK; scope unique constraint rebuilt as `UNIQUE NULLS NOT DISTINCT (user_id, role_id, company_id, site_id, department_id)`; `user_roles` site/department indexes.
- **0010** — replace permissive `user_profiles` self-insert/update with **admin-only** insert/update (own company); split `user_roles` `FOR ALL` into **INSERT + UPDATE** (no DELETE); revoke DELETE on `user_profiles`/`user_roles`/`users`.
- **Rollback** — reverse steps embedded (commented) in each migration; DELETE grants intentionally not restored.

## 3. Self-Check A — every requirement maps to "already present" or a migration step

See §1 table: G1, G2, G10, G11, G12 = **already present**; G3, G4, G5, G6, G7, G8, G9 = **migration needed**, each mapped to a specific step in 0009/0010. 12/12 covered, no gap.

## 4. Self-Check B — the 4 new Administrator-only actions → enforcing policy

| Matrix action (MVP1_2.md) | Emp | Sup | SO | Mgr | Admin | Enforcing policy (server-side) |
|---|:--:|:--:|:--:|:--:|:--:|---|
| Invite / Provision User | ❌ | ❌ | ❌ | ❌ | ✅ | `user_profiles_admin_insert` + `user_roles_admin_insert` (rank≥5, own company); invite via service-role Edge Fn (5A) |
| Assign / Change Role & Scope | ❌ | ❌ | ❌ | ❌ | ✅ | `user_roles_admin_insert` / `user_roles_admin_update` (rank≥5, own company) |
| Deactivate / Reactivate User | ❌ | ❌ | ❌ | ❌ | ✅ | `user_profiles_admin_update` (status change; rank≥5); no DELETE grant |
| Reset User Password (admin-initiated) | ❌ | ❌ | ❌ | ❌ | ✅ | service-role Edge Fn only (5A); no client policy grants it |

All four are Administrator-only and enforced at RLS/Edge-Function, not just UI. Deny-by-default holds for ranks 1–4.

### Claims re-verification (G10)
- `app.user_rank()` returns `max(rank)` across the user's `user_roles` rows within their company → unaffected by adding `site_id`/`department_id`; a user with multiple scope-aware rows still resolves to their highest privilege for write-gates.
- `app.current_site_id()` / `app.current_department_id()` read the user's **home** scope from `user_profiles` (unchanged). Per-role scope (site/department on `user_roles`) is available for finer policies if introduced later, but MVP1 visibility continues to use home scope + rank (2B). No regression.

## 5. Ledger update note (recorded on approval)

- **§1 additions:** `user_roles.department_id`; `user_profiles.status` + `invited_at`/`activated_at`/`deactivated_at`; enum `user_status`.
- **§5a (new):** identity 3-layer model; scope-aware `user_roles` (site+department nullable, NULL=company-wide, `NULLS NOT DISTINCT` uniqueness); lifecycle `invited→active→suspended→deactivated` (no hard delete; `is_active` deprecated); invite-based admin-only provisioning via service-role Edge Functions; 4 admin-only RBAC rows; licensing deferred to MVP2.
- **User-table write posture:** admin-only INSERT/UPDATE scoped to own company; no client DELETE on any user table.

## 6. Notes / Open items
- **OQ-UM1:** Self-service profile edits (user updating own phone/avatar) are now blocked by admin-only writes. If desired later, add a narrow self-UPDATE policy limited to non-privileged columns. Flagged, not built (spec is admin-provisioned).
- **Bootstrap:** the first company + first Administrator must be provisioned out-of-band (ops/seed or a service-role bootstrap), since all client user-writes now require an existing admin. Handled in Prompt 5A / deployment (Prompt 18).
- No Flutter code in this prompt (schema/RLS delta only). Edge Functions + admin UI are Prompt 5A.

**End of Prompt 4C deliverable.**
