// path: lib/core/config/app_config.dart
/// Environment configuration read from --dart-define at build time.
/// No secrets are hardcoded (Security Requirements). Per-flavour values
/// (Dev/Test/UAT/Prod) are wired in Prompt 18.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.flavor,
    required this.authRedirectUrl,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String flavor;

  /// Where Supabase sends the user after they click an invite or password-reset
  /// link. Must be registered under Authentication → URL Configuration →
  /// Redirect URLs on the Supabase project, and matched by the intent-filter in
  /// AndroidManifest.xml — all three have to agree or the link silently falls
  /// back to the project's Site URL (which defaulted to http://localhost:3000
  /// and is why these emails went nowhere).
  final String authRedirectUrl;

  bool get isProduction => flavor == 'prod';

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      flavor: String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
      authRedirectUrl: String.fromEnvironment(
        'AUTH_REDIRECT_URL',
        defaultValue: 'ohsshield://auth-callback',
      ),
    );
  }
}
