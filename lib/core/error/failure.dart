// path: lib/core/error/failure.dart
/// Domain-facing failure hierarchy. Repositories translate infrastructure
/// exceptions into these so the domain/presentation layers never depend on
/// Supabase/Drift/socket types. (The underlying exception is logged at the
/// translation point by `guardAsync`, so failures carry only a user message.)
sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No / unreliable connectivity, or request timed out.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// Authentication/session problem (invalid credentials, expired session).
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

/// Server/PostgREST/Edge Function error.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on the server.']);
}

/// Local persistence (Drift/SQLite) error.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error.']);
}

/// Input/business-rule validation error.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});
  final Map<String, String> fieldErrors;
}

/// RLS/RBAC denial — user lacks permission for the action.
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Not available for your role.']);
}

/// Fallback for unmapped errors.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unexpected error.']);
}
