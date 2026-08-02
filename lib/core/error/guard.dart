// path: lib/core/error/guard.dart
import 'dart:async';
import 'dart:io';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Runs [action] and maps infrastructure exceptions to a [Failure], returning a
/// [Result]. This is the single choke-point where Supabase/Drift/socket errors
/// become domain failures — keeps try/catch out of every repository method.
Future<Result<T>> guardAsync<T>(
  Future<T> Function() action, {
  required LoggerService logger,
  String? context,
}) async {
  try {
    return Ok(await action());
  } on AuthException catch (e, s) {
    logger.warn('Auth error${context == null ? '' : ' [$context]'}', e, s);
    return Err(AuthFailure(e.message));
  } on PostgrestException catch (e, s) {
    // 42501 = insufficient_privilege (RLS denial) -> permission failure.
    final failure = e.code == '42501'
        ? const PermissionFailure()
        : ServerFailure(e.message);
    logger.error('Postgrest error${context == null ? '' : ' [$context]'}', e, s);
    return Err(failure);
  } on StorageException catch (e, s) {
    logger.error('Storage error${context == null ? '' : ' [$context]'}', e, s);
    return Err(ServerFailure(e.message));
  } on SocketException catch (e, s) {
    logger.warn('Network error${context == null ? '' : ' [$context]'}', e, s);
    return const Err(NetworkFailure());
  } on TimeoutException catch (e, s) {
    logger.warn('Timeout${context == null ? '' : ' [$context]'}', e, s);
    return const Err(NetworkFailure('Request timed out.'));
  } catch (e, s) {
    logger.error('Unexpected error${context == null ? '' : ' [$context]'}', e, s);
    return const Err(UnknownFailure());
  }
}
