// path: lib/features/auth/presentation/providers/auth_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/auth/session_providers.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/application/auth_use_cases.dart';
import 'package:ohs_shield_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_user.dart';
import 'package:ohs_shield_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return result.when(
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
  }

  Future<void> signOut() async {
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
    final res = await ref.read(sendPasswordResetUseCaseProvider).call(email);
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
