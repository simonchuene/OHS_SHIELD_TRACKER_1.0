// path: lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/auth/data/dtos/user_profile_dto.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_user.dart';
import 'package:ohs_shield_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [AuthRepository]. Session persistence + secure token storage
/// are handled by supabase_flutter (Keychain/Keystore-backed local storage);
/// this repo layers profile + scope-aware role loading on top.
final class AuthRepositoryImpl extends BaseRepository implements AuthRepository {
  AuthRepositoryImpl(this._client, LoggerService logger) : super(logger);

  final SupabaseClient _client;

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<void> authStateChanges() =>
      _client.auth.onAuthStateChange.map((_) {});

  @override
  Future<Result<void>> signIn({required String email, required String password}) {
    return run(
      () async {
        await _client.auth.signInWithPassword(email: email, password: password);
      },
      context: 'signIn',
    );
  }

  @override
  Future<Result<void>> signOut() =>
      run(() => _client.auth.signOut(), context: 'signOut');

  @override
  Future<Result<void>> sendPasswordReset(String email) => run(
        () => _client.auth.resetPasswordForEmail(email),
        context: 'sendPasswordReset',
      );

  @override
  Future<Result<AppUser?>> loadCurrentUser() {
    return run<AppUser?>(
      () async {
        final authUser = _client.auth.currentUser;
        if (authUser == null) return null;

        final profileJson = await _client
            .from('user_profiles')
            .select()
            .eq('user_id', authUser.id)
            .maybeSingle();
        if (profileJson == null) return null; // invited, not yet activated

        final dto = UserProfileDto.fromJson(profileJson);

        // Nested read: user_roles -> roles(code). RLS scopes to the same company.
        final roleRows = await _client
            .from('user_roles')
            .select('roles(code)')
            .eq('user_id', authUser.id);

        final codes = <String>[
          for (final row in roleRows)
            if (row['roles'] is Map && (row['roles'] as Map)['code'] != null)
              (row['roles'] as Map)['code'] as String,
        ];

        return dto.toEntity(email: authUser.email ?? '', roleCodes: codes);
      },
      context: 'loadCurrentUser',
    );
  }
}
