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

  static const String _devApiBase = 'http://10.0.2.2:8080/api';
  static const String _prodApiBase = 'https://api.oneminuteludo.com/api';

  static const String _devSocketUrl = 'http://10.0.2.2:8080';
  static const String _prodSocketUrl = 'https://api.oneminuteludo.com';

  /// REST API base URL for the active environment.
  static String get apiBaseUrl =>
      environment == Environment.development ? _devApiBase : _prodApiBase;

  /// Socket.IO server URL for the active environment.
  static String get socketUrl =>
      environment == Environment.development ? _devSocketUrl : _prodSocketUrl;

  // ─── Timeouts ────────────────────────────────────────────────────────────────

  /// Default HTTP request timeout.
  static const Duration httpTimeout = Duration(seconds: 15);
}
