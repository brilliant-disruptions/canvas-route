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

  /// Modes this build ships, comma-separated ids in picker order; the first is the default.
  /// v1 launches Yard Sales alone. Pass `yard_sales,card_drops,field_sales` for every vertical.
  static const launchModes = String.fromEnvironment('LAUNCH_MODES', defaultValue: 'yard_sales');

  static bool get hasGoogleKey => googleMapsApiKey.isNotEmpty;
  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
