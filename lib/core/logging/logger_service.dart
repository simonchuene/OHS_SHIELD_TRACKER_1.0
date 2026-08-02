// path: lib/core/logging/logger_service.dart
import 'package:logger/logger.dart';

/// Thin logging facade over the `logger` package. Domain/data layers depend on
/// this interface, not on `logger` directly. Never log PII (POPIA) — callers
/// pass IDs, not names/contact details.
abstract interface class LoggerService {
  void debug(String message, [Object? error, StackTrace? stack]);
  void info(String message, [Object? error, StackTrace? stack]);
  void warn(String message, [Object? error, StackTrace? stack]);
  void error(String message, [Object? error, StackTrace? stack]);
}

class AppLogger implements LoggerService {
  AppLogger({bool verbose = false})
      : _logger = Logger(
          filter: verbose ? DevelopmentFilter() : ProductionFilter(),
          printer: PrettyPrinter(methodCount: 0, errorMethodCount: 6),
        );

  final Logger _logger;

  @override
  void debug(String m, [Object? e, StackTrace? s]) => _logger.d(m, error: e, stackTrace: s);
  @override
  void info(String m, [Object? e, StackTrace? s]) => _logger.i(m, error: e, stackTrace: s);
  @override
  void warn(String m, [Object? e, StackTrace? s]) => _logger.w(m, error: e, stackTrace: s);
  @override
  void error(String m, [Object? e, StackTrace? s]) => _logger.e(m, error: e, stackTrace: s);
}
