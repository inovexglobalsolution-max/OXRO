/// Build-time configuration via `--dart-define` / `--dart-define-from-file`.
///
/// Never put the Supabase secret/service-role key here: this file ships in
/// the app binary.
class AppEnv {
  AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
