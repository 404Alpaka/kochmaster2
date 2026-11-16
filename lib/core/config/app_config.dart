/// Public client configuration. Authorization is enforced by Supabase RLS.
/// Override these values with --dart-define for another environment.
abstract final class AppConfig {
  static const useDemo = bool.fromEnvironment('USE_DEMO');
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xeujowhyrwymrgjvfjhz.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_8X-wCEWZiNgxSGcC-2UBpA_tOCHVaYN',
  );
}
