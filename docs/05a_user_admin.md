# OHS Shield Tracker — User & Access Administration (Prompt 5A)

> MVP Module 2. Admin-only user-lifecycle layer on top of Auth (Prompt 5). Depends on 4C (reconciled schema), 5 (session/RBAC), 4A (foundation), 4B (sync). Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`. **No billing/seats/subscriptions** (deferred to MVP2).
>
> **Status:** Draft for human approval. Review-ready (needs `flutter pub get`, `build_runner`, and `supabase functions deploy user-admin` + SMTP for invite emails).

## Files

**Server**
- [supabase/functions/user-admin/index.ts](../supabase/functions/user-admin/index.ts) — service-role Edge Function; every privileged mutation + audit.
- [supabase/migrations/0011_user_activation_trigger.sql](../supabase/migrations/0011_user_activation_trigger.sql) — invited→active on email confirm.

**Flutter feature** (`lib/features/user_admin/`)
- domain: `entities/{role_assignment, managed_user, user_filter}.dart`, `user_lifecycle.dart`, `repositories/user_admin_repository.dart`
- data: `user_admin_repository_impl.dart` (PostgREST reads + `functions.invoke` writes)
- application: `user_admin_use_cases.dart`
- presentation: `providers/user_admin_providers.dart`, `screens/{user_list, user_detail, invite_user}_screen.dart`
- tests: `test/features/user_admin/user_lifecycle_test.dart`

Router: `/admin/users`, `/admin/users/new`, `/admin/users/:id` under **More**, Administrator-guarded.

## 1. Architecture

- **Privileged ops are server-only.** Invite, resend, assign roles, suspend, reactivate, deactivate, admin password reset all run in the `user-admin` Edge Function under the **service role** — never the client. The function: (1) authenticates the caller, (2) verifies Administrator + resolves company, (3) enforces same-company-only, (4) applies lifecycle guards, (5) writes `audit_logs` before/after.
- **Reads** (list/search, detail) use RLS-scoped PostgREST — an admin can only read their own company's users (2B/4C).
- **Client is a thin caller** via `supabase.functions.invoke('user-admin', ...)`; it holds no service key.

## 2. Provisioning flow (invite-based, no self-registration)
1. Admin submits Invite form → `user-admin {action:'invite'}`.
2. Function calls `auth.admin.inviteUserByEmail` (creates `auth.users`; trigger mirrors into `public.users`), inserts `user_profiles` (`status='invited'`, company/site/dept), inserts scope-aware `user_roles`, writes `user.invited` audit.
3. Invitee opens the emailed link, sets a password → `email_confirmed_at` set → `handle_user_confirmed()` flips profile `invited → active`.

## 3. Lifecycle enforcement
`invited → active → suspended → deactivated`, with reactivation back to `active`. Enforced in **three** places: client UI (disable illegal actions), client use case (fail fast), and the Edge Function `ALLOWED` map (authoritative). Deactivation/suspension **bans the auth user** (revokes login) and sets status; the record is **never deleted** (retains historical ownership + audit). Self-check §6.2.

## 4. Offline behaviour
Privileged actions require connectivity (`UserAdminActionController` checks `connectivityStatusProvider`; when offline it surfaces "This action needs an internet connection" rather than queuing — they can't be safely deferred through the sync engine because they run service-role server-side). List/search read via PostgREST and can display cached results.

## 5. Validation & POPIA
- Email format + required first/last name (client + server); email is globally unique in `auth.users` (⊇ within-company uniqueness).
- Required company binding at invite (company = admin's own); optional site/department; role required; scope explicit (company-wide vs site/department).
- Personal fields minimised (name, optional job title/phone) — POPIA.

---

## 6. Self-Check

### 6.1 Role × action — the 4 user-admin matrix rows are Administrator-only, server-enforced

| Action (MVP1_2.md) | Emp | Sup | SO | Mgr | Admin | Server enforcement |
|---|:--:|:--:|:--:|:--:|:--:|---|
| Invite / Provision User | ❌ | ❌ | ❌ | ❌ | ✅ | Edge Fn admin check (rank/`administrator`) + `user_profiles_admin_insert`/`user_roles_admin_insert` RLS |
| Assign / Change Role & Scope | ❌ | ❌ | ❌ | ❌ | ✅ | Edge Fn `assignRoles` (admin+same company) + `user_roles_admin_*` RLS |
| Deactivate / Reactivate User | ❌ | ❌ | ❌ | ❌ | ✅ | Edge Fn `deactivate`/`reactivate` (status change + ban) + `user_profiles_admin_update` RLS; no DELETE |
| Reset User Password (admin) | ❌ | ❌ | ❌ | ❌ | ✅ | Edge Fn `resetPassword` (service role); no client policy grants it |

Non-admins are rejected by the Edge Function (403) **and** by RLS if they attempted direct writes. Router guard hides `/admin/**` for rank < 5 (UX only).

### 6.2 Lifecycle state-transition table with guards

| From \ Action | Suspend | Reactivate | Deactivate | Resend invite | Reset pw |
|---|---|---|---|---|---|
| **invited** | ✖ blocked | ✖ | → deactivated | ✔ (invited only) | ✖ |
| **active** | → suspended | ✖ | → deactivated | ✖ | ✔ |
| **suspended** | ✖ | → active | → deactivated | ✖ | ✔ |
| **deactivated** | ✖ | → active | ✖ (already) | ✖ | ✖ |

Guard = `ALLOWED[from].contains(to)` (Edge Fn) mirrored by `UserLifecycle.canPerform` (client). Illegal transitions return HTTP 409 server-side and are disabled in the UI. **No transition deletes the user.**

### 6.3 Business rules
| Rule | Where |
|---|---|
| No open self-registration | invite-only; no signup path; profile writes admin-only (0010) |
| Exactly one company_id; multiple scope-aware roles | `user_profiles.company_id` NOT NULL; N `user_roles` rows |
| Never hard-delete a user | status change + ban; DELETE grants revoked (0010); Edge Fn never deletes profiles/users |
| Administrator scope = own company | Edge Fn `loadTarget` rejects cross-company; RLS company scoping |

### 6.4 Tests
`user_lifecycle_test` — allowed transitions + `canPerform` guards for all actions/states.

## 7. Ledger / notes
- Edge Function **`user-admin`** added to the server-side function set; activation trigger `handle_user_confirmed` added (0011).
- No new *domain* decisions — user model + admin-only posture were recorded in 4C. 5A implements them.
- **Bootstrap** (still open, from 4C): first company + first Administrator must be provisioned out-of-band (seed/ops), since all client user-writes now require an existing admin — finalised in Prompt 18 (deployment).

**End of Prompt 5A deliverable.**
