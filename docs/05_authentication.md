# OHS Shield Tracker — Authentication Module (Prompt 5)

> First full feature module. Built against the approved architecture, foundation (4A), sync engine (4B), and the reconciled scope-aware user model (4C). Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `flutter pub get` + `dart run build_runner build` for `*.freezed.dart` / `*.g.dart`).

## Files

```
lib/features/auth/
├── domain/
│   ├── entities/{app_role, user_status, app_user}.dart
│   └── repositories/auth_repository.dart
├── data/
│   ├── dtos/user_profile_dto.dart
│   └── repositories/auth_repository_impl.dart
├── application/auth_use_cases.dart          # SignIn, SignOut, SendPasswordReset, LoadCurrentUser
└── presentation/
    ├── providers/auth_providers.dart         # @riverpod DI + CurrentUser + controllers
    └── screens/{login_screen, forgot_password_screen}.dart
lib/core/utils/validators.dart                # pure, reusable
test/features/auth/*, test/core/utils/validators_test.dart
```
Router updated: real Login/Forgot screens + role guard via `authRoleRankProvider`.

## 1. Domain & DTOs
- `AppRole` — 5 locked roles with `rank` + `code` + capability helpers (matrix thresholds).
- `UserStatus` — `invited/active/suspended/deactivated`; `canSignIn == active`.
- `AppUser` (freezed) — identity + scope (company/site/department) + `status` + scope-aware `roles`; `highestRank`, `primaryRole`, `initials`, `isActive`.
- `UserProfileDto` (freezed+json) — `user_profiles` row; `toEntity(email, roleCodes)` maps to `AppUser`.

## 2. Repository & Supabase integration
`AuthRepositoryImpl` (extends `BaseRepository`, so every call is guarded → `Result`):
- `signIn` → `signInWithPassword`; `signOut`; `sendPasswordReset` → `resetPasswordForEmail`.
- `loadCurrentUser` → reads `user_profiles` + nested `user_roles → roles(code)` for `auth.uid()`, RLS-scoped; returns null when no session or no activated profile (invited).
- `authStateChanges` bridges `onAuthStateChange`.

## 3. Use cases (RBAC + status gate)
- `SignInUseCase` signs in, loads the profile, and **rejects non-active accounts** (signs back out) — enforcing "deactivation blocks login".
- `LoadCurrentUserUseCase` terminates a session whose profile was later suspended/deactivated.
- `SignOutUseCase`, `SendPasswordResetUseCase`.

## 4. Providers (state management)
- `authRepositoryProvider`, one provider per use case (codegen `@riverpod`).
- `CurrentUser` (`@riverpod` AsyncNotifier) — rebuilds on every auth change; exposes `AppUser?`; `signOut()` invalidates.
- `authRoleRankProvider` — client rank for conditional UI + router guard (RLS authoritative).
- `SignInController` / `ForgotPasswordController` — `AsyncValue` action state for the screens.

## 5. Screens (mobile-first, Prompt 3)
- **Login** — hierarchy Logo → Name → Tagline → Email → Password → Log in; brand accent stripe (Item 1b); filled-green CTA (16px); inline validation; failure snackbar; on success the auth-state change auto-redirects to `/dashboard`.
- **Forgot Password** — email → reset link, with a confirming "check your email" state (no account enumeration).

## 6. Session management & secure storage
- **Persistence:** handled by `supabase_flutter` (session cached in platform-secure storage; auto token refresh). App restart resumes the session; router redirects accordingly.
- **Secure storage:** `flutter_secure_storage` (Ledger §5) available via `secureStorageProvider` for any additional sensitive values; auth tokens remain managed by Supabase. No PII persisted in plaintext (POPIA).
- **Secure logout:** `CurrentUser.signOut()` → `supabase.auth.signOut()` clears the session; `refreshListenable` fires → router redirects to `/login`.

## 7. RBAC integration
- Client roles loaded from scope-aware `user_roles`; `highestRank` drives conditional rendering + the Audit route guard.
- **Server remains authoritative** — RLS (2B/4C) enforces every action regardless of client state; the client never widens its own scope.

---

## 8. Self-Check

### 8.1 Business rules
| Rule | Where enforced |
|---|---|
| Session persistence | supabase_flutter secure local session + auto-refresh (§6) |
| Secure logout | `CurrentUser.signOut()` → clears session → router redirect (§6) |
| Password reset | `ForgotPasswordScreen` + `SendPasswordResetUseCase` (§5) |
| Role-based access (matrix) | roles → `highestRank` (UI) + RLS (server) (§7) |
| Deactivation blocks login | `SignInUseCase` active-status gate; `LoadCurrentUserUseCase` terminates inactive session (§3) |
| Mobile-first UX | 390-first layouts, ≥44 touch targets, autofill hints (§5) |

### 8.2 Status → sign-in allowed
| Status | Sign in? | Handling |
|---|:--:|---|
| invited | ❌ | no activated profile → rejected + signed out |
| active | ✅ | proceed |
| suspended | ❌ | signed out, message shown |
| deactivated | ❌ | signed out, message shown |

### 8.3 Tests
- `app_role_test` — code→rank mapping + capability thresholds vs matrix.
- `app_user_test` — highestRank across multiple roles, initials, active gate.
- `validators_test` — email/password rules.
- `login_screen_test` (widget) — empty-submit shows inline validation before any network call.

## 9. Notes
- No architecture redesign; consumes 4A/4B/4C as-is.
- `core/auth/session_providers.dart` role-rank stub removed — superseded by `authRoleRankProvider`.
- No new Ledger decisions (conventions already recorded in 4A; user model in 4C). Auth confirms the secure-storage + RBAC-integration slots as implemented.

**End of Prompt 5 deliverable.**
