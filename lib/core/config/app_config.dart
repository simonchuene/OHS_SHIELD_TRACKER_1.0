// path: lib/core/config/app_config.dart
/// Environment configuration read from --dart-define at build time.
/// No secrets are hardcoded (Security Requirements). Per-flavour values
/// (Dev/Test/UAT/Prod) are wired in Prompt 18.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.flavor,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String flavor;

  bool get isProduction => flavor == 'prod';

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      flavor: String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    );
  }
}
