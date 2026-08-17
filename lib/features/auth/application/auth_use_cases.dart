// path: lib/features/auth/application/auth_use_cases.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_user.dart';
import 'package:ohs_shield_tracker/features/auth/domain/repositories/auth_repository.dart';

/// One intent per use case (application layer). Kept in one file as they are all
/// thin orchestrations over [AuthRepository]; each is independently injectable.

class SignInUseCase {
  const SignInUseCase(this._repo);
  final AuthRepository _repo;

  /// Signs in, then verifies the profile is `active`. A suspended/deactivated
  /// account is signed straight back out and rejected (business rule:
  /// deactivation blocks login).
  Future<Result<AppUser>> call({required String email, required String password}) async {
    final signIn = await _repo.signIn(email: email, password: password);
    if (signIn.isFailure) return Err(signIn.failureOrNull!);

    final loaded = await _repo.loadCurrentUser();
    return switch (loaded) {
      Err(:final failure) => Err(failure),
      Ok(value: final user) => await _guardActive(user),
    };
  }

  Future<Result<AppUser>> _guardActive(AppUser? user) async {
    if (user == null) {
      await _repo.signOut();
      return const Err(AuthFailure('No active profile for this account. Contact your administrator.'));
    }
    if (!user.isActive) {
      await _repo.signOut();
      return const Err(AuthFailure('Your account is not active. Contact your administrator.'));
    }
    return Ok(user);
  }
}

class SignOutUseCase {
  const SignOutUseCase(this._repo);
  final AuthRepository _repo;
  Future<Result<void>> call() => _repo.signOut();
}

class SendPasswordResetUseCase {
  const SendPasswordResetUseCase(this._repo);
  final AuthRepository _repo;
  Future<Result<void>> call(String email, {String? redirectTo}) =>
      _repo.sendPasswordReset(email, redirectTo: redirectTo);
}

class LoadCurrentUserUseCase {
  const LoadCurrentUserUseCase(this._repo);
  final AuthRepository _repo;

  /// Loads the current user and enforces the active-status gate (a session whose
  /// profile was later suspended/deactivated is terminated).
  Future<Result<AppUser?>> call() async {
    final loaded = await _repo.loadCurrentUser();
    return switch (loaded) {
      Err() => loaded,
      Ok(value: final user) => await _enforce(user),
    };
  }

  Future<Result<AppUser?>> _enforce(AppUser? user) async {
    if (user != null && !user.isActive) {
      await _repo.signOut();
      return const Ok(null);
    }
    return Ok(user);
  }
}

/// Sets a password for the current session. Reached from the set-password
/// screen after an invite or reset link has established a session.
class SetPasswordUseCase {
  const SetPasswordUseCase(this._repo);
  final AuthRepository _repo;

  Future<Result<void>> call(String password) => _repo.setPassword(password);
}
