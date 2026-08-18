// path: lib/features/auth/presentation/providers/auth_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/auth/session_providers.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/application/auth_use_cases.dart';
import 'package:ohs_shield_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_user.dart';
import 'package:ohs_shield_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/password_setup_gate.dart';

part 'auth_providers.g.dart';

// --- Repository + use cases (DI) ------------------------------------------

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepositoryImpl(
      ref.watch(supabaseClientProvider),
      ref.watch(loggerProvider),
    );

@riverpod
SignInUseCase signInUseCase(SignInUseCaseRef ref) =>
    SignInUseCase(ref.watch(authRepositoryProvider));

@riverpod
SignOutUseCase signOutUseCase(SignOutUseCaseRef ref) =>
    SignOutUseCase(ref.watch(authRepositoryProvider));

@riverpod
SendPasswordResetUseCase sendPasswordResetUseCase(SendPasswordResetUseCaseRef ref) =>
    SendPasswordResetUseCase(ref.watch(authRepositoryProvider));

@riverpod
SetPasswordUseCase setPasswordUseCase(SetPasswordUseCaseRef ref) =>
    SetPasswordUseCase(ref.watch(authRepositoryProvider));

@riverpod
LoadCurrentUserUseCase loadCurrentUserUseCase(LoadCurrentUserUseCaseRef ref) =>
    LoadCurrentUserUseCase(ref.watch(authRepositoryProvider));

// --- Current user (session-backed) ----------------------------------------

/// The signed-in [AppUser] (profile + roles), or null when signed out. Rebuilds
/// on every Supabase auth change; enforces the active-status gate via the use case.
@riverpod
class CurrentUser extends _$CurrentUser {
  @override
  Future<AppUser?> build() async {
    ref.watch(authStateChangesProvider); // rebuild on sign-in/out/refresh
    final client = ref.watch(supabaseClientProvider);
    if (client.auth.currentSession == null) return null;
    final result = await ref.watch(loadCurrentUserUseCaseProvider).call();
    final user = result.when(
      ok: (u) => u,
      err: (f) {
        // Profile load failed. If the session is expired (couldn't be refreshed)
        // and the server actively rejected the request — rather than a transient
        // network error — the session is effectively dead. Clear it locally so
        // the router redirects to login instead of stranding the user on an
        // authed screen showing "Not signed in".
        if (f is! NetworkFailure && (client.auth.currentSession?.isExpired ?? false)) {
          unawaited(client.auth.signOut(scope: SignOutScope.local));
        }
        return null;
      },
    );

    // Claim the offline store before anything reads it. The cache is keyed only
    // by (entityType, entityId) and every list merges it wholesale, so data left
    // behind by a previous account would render alongside this user's own —
    // across companies. Awaited here because the router gates every list screen
    // on this provider, which puts the wipe ahead of the first cached read.
    if (user != null) {
      final wiped = await ref.read(appDatabaseProvider).claimForUser(user.id);
      if (wiped) {
        ref.read(loggerProvider).info('Local store belonged to another user; cleared');
      }
    }
    return user;
  }

  Future<void> signOut() async {
    // Before dropping the session, not after: a device handed to someone else
    // must not still hold this user's records, and a failure here would leave
    // them readable. `claimForUser` re-checks on next sign-in regardless.
    await ref.read(appDatabaseProvider).releaseLocalData();
    await ref.read(signOutUseCaseProvider).call();
    ref.invalidateSelf();
  }
}

/// Client-side role rank for conditional UI + router role guard (RLS is
/// authoritative). Null while unknown/loading.
@riverpod
int? authRoleRank(AuthRoleRankRef ref) =>
    ref.watch(currentUserProvider).valueOrNull?.highestRank;

// --- Screen action controllers --------------------------------------------

@riverpod
class SignInController extends _$SignInController {
  // Holds an AsyncValue<void> directly (a plain Notifier) rather than a
  // FutureOr<void> build (an AsyncNotifier): the latter completes an internal
  // `.future` on the synchronous build, so manually driving state through
  // AsyncLoading -> AsyncData threw "Future already completed".
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Returns true on success; on failure exposes the error via [state].
  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final res = await ref.read(signInUseCaseProvider).call(email: email, password: password);
    return res.when(
      ok: (_) {
        state = const AsyncData(null);
        ref.invalidate(currentUserProvider);
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }
}

@riverpod
class ForgotPasswordController extends _$ForgotPasswordController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit(String email) async {
    state = const AsyncLoading();
    // Without redirectTo the email lands on the project's Site URL, which
    // defaulted to http://localhost:3000 — the reset mail sent fine and went
    // nowhere.
    final res = await ref.read(sendPasswordResetUseCaseProvider)
        .call(email, redirectTo: ref.read(appConfigProvider).authRedirectUrl);
    return res.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }
}

/// Completes an invite or a password reset: both arrive via an email deep link
/// that establishes a session, then need a password chosen for it.
@riverpod
class SetPasswordController extends _$SetPasswordController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit(String password) async {
    state = const AsyncLoading();
    final res = await ref.read(setPasswordUseCaseProvider).call(password);
    return res.when(
      ok: (_) {
        state = const AsyncData(null);
        // 0020's trigger flips an invited profile to 'active' on this write, so
        // re-read the user before dropping the gate — otherwise the stale
        // 'invited' status would immediately re-raise it and trap the user on
        // this screen.
        ref.invalidate(currentUserProvider);
        ref.read(passwordSetupGateProvider).clear();
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }
}
