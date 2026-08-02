/// Target environment for the current build.
///
/// Switch to [Environment.production] before building a release APK.
enum Environment { development, production }

/// Application-level configuration for 1 Minute Ludo.
///
/// All environment-specific URLs are derived from [environment] so that
/// switching between dev and prod requires changing only one line.
class AppConfig {
  AppConfig._();

  // ─── Active environment ──────────────────────────────────────────────────────

  /// Change this to [Environment.production] for a production build.
  static const Environment environment = Environment.development;

  // ─── Backend URLs ────────────────────────────────────────────────────────────

  static const String _devApiBase =
      'https://08e479f4-e9e3-4d3a-b2f5-a41ecd694577-00-1svgwq6birp41.sisko.replit.dev/api';
  static const String _prodApiBase = 'https://api.oneminuteludo.com/api';

  static const String _devSocketUrl =
      'https://08e479f4-e9e3-4d3a-b2f5-a41ecd694577-00-1svgwq6birp41.sisko.replit.dev';
  static const String _prodSocketUrl = 'https://api.oneminuteludo.com';

  /// REST API base URL for the active environment.
  static String get apiBaseUrl =>
      environment == Environment.development ? _devApiBase : _prodApiBase;

  /// Socket.IO server URL for the active environment.
  static String get socketUrl =>
      environment == Environment.development ? _devSocketUrl : _prodSocketUrl;

  // ─── Google Sign-In ──────────────────────────────────────────────────────────

  /// Web / server OAuth 2.0 client ID from Google Cloud Console.
  ///
  /// Injected at build time via --dart-define=GOOGLE_SERVER_CLIENT_ID=<value>.
  /// Must match the GOOGLE_CLIENT_ID secret on the backend.
  ///
  /// Example (debug):
  ///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=123456.apps.googleusercontent.com
  /// Example (release):
  ///   flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=123456.apps.googleusercontent.com
  ///
  /// Returns an empty string when not supplied (Google Sign-In will show an
  /// error, matching the 503 the backend returns without GOOGLE_CLIENT_ID).
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  // ─── Timeouts ────────────────────────────────────────────────────────────────

  /// Default HTTP request timeout.
  static const Duration httpTimeout = Duration(seconds: 15);
}
