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
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  bool isOnline(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
});
