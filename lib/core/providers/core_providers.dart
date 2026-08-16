// path: lib/core/providers/core_providers.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ohs_shield_tracker/core/config/app_config.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod is the DI container for the whole app. Infrastructure singletons are
/// exposed as providers; `main.dart` overrides [appConfigProvider] and
/// [supabaseClientProvider] after async init. Feature providers (Prompt 5+) use
/// `@riverpod` code-gen and depend on these.

/// Overridden in main() with the flavour config.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in main()');
});

/// Overridden in main() after Supabase.initialize().
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError('supabaseClientProvider must be overridden in main()');
});

final loggerProvider = Provider<LoggerService>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppLogger(verbose: !config.isProduction);
});

/// Secure token/credential storage (Master Prompt: Secure Storage Strategy).
/// Auth tokens are managed by supabase_flutter; this is for any additional
/// sensitive values (e.g. cached role claims) — never plaintext PII.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// Stream of online/offline status, consumed by the sync engine (Prompt 4B)
/// and the global offline banner (Prompt 3 §9.4).
Stream<bool> _connectivityStream(Connectivity connectivity) async* {
  bool isOnline(List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none);
  // Current state first, then changes — consumers must know whether they are
  // online before anything toggles, or the sync engine idles until the next
  // connectivity event.
  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
}

final connectivityStatusProvider =
    StreamProvider<bool>((ref) => _connectivityStream(ref.watch(connectivityProvider)));

/// Builds a **fresh** online/offline stream for consumers that need a
/// `Stream<bool>` rather than an `AsyncValue` — the sync engine and the
/// attachment upload queue each take one at construction.
///
/// A factory, not a stream: Riverpod deprecated `someProvider.stream` (removed
/// in 3.0), and the obvious replacements are both wrong here. Caching one
/// instance would hand the same **single-subscription** `async*` stream to two
/// listeners, which throws; converting it to a broadcast stream would deliver
/// the initial state only to whichever subscribed first. Each consumer gets its
/// own subscription instead.
final connectivityStreamFactoryProvider = Provider<Stream<bool> Function()>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return () => _connectivityStream(connectivity);
});
