/// Build-time configuration. Pass with `--dart-define` or a `--dart-define-from-file=.env.json`.
///
/// Never commit real keys. See README for the expected `.env.json` shape.
abstract final class Env {
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep-link scheme used for magic links and OAuth callbacks.
  static const authRedirect = String.fromEnvironment(
    'AUTH_REDIRECT',
    defaultValue: 'canvasroute://auth-callback',
  );

  /// Public web origin for shared route / host sale pages (Phase 5).
  static const webOrigin = String.fromEnvironment(
    'WEB_ORIGIN',
    defaultValue: 'https://canvasroute.app',
  );

  static bool get hasGoogleKey => googleMapsApiKey.isNotEmpty;
  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
