// path: lib/repositories/base_repository.dart
import 'package:ohs_shield_tracker/core/error/guard.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';

/// Base class for all repository implementations (Repository Pattern).
///
/// Cross-cutting/base repository contracts live in `lib/repositories`; concrete
/// feature repositories live in `features/<feature>/data/repositories` and
/// extend this to inherit the [run] guard so every data call funnels through
/// [guardAsync] (uniform exception -> Failure mapping).
abstract base class BaseRepository {
  const BaseRepository(this.logger);
  final LoggerService logger;

  /// Wraps a data operation, mapping infrastructure exceptions to Failures.
  Future<Result<T>> run<T>(Future<T> Function() action, {String? context}) =>
      guardAsync(action, logger: logger, context: context);
}
