// path: lib/features/auth/domain/repositories/auth_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_user.dart';

/// Authentication contract (domain layer). Implemented in data/ against Supabase
/// Auth + PostgREST. Returns [Result] — never throws to callers.
abstract interface class AuthRepository {
  /// True when a persisted session exists (session persistence is handled by
  /// supabase_flutter's secure local storage).
  bool get hasSession;

  /// Auth id of the signed-in user, or null.
  String? get currentUserId;

  /// Emits on every auth state change (sign-in/out, token refresh).
  Stream<void> authStateChanges();

  Future<Result<void>> signIn({required String email, required String password});

  Future<Result<void>> signOut();

  /// Sends the reset email. [redirectTo] is the deep link the email should
  /// return to; without it Supabase falls back to the project's Site URL.
  Future<Result<void>> sendPasswordReset(String email, {String? redirectTo});

  /// Sets a password for the *currently authenticated* session. Used by both
  /// flows that arrive via an email link: an invitee choosing their first
  /// password, and a user completing a reset.
  Future<Result<void>> setPassword(String newPassword);

  /// Loads the full [AppUser] (profile + scope-aware roles) for the current
  /// session. Returns null when there is no session.
  Future<Result<AppUser?>> loadCurrentUser();
}
