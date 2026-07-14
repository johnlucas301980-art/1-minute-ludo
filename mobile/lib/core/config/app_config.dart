/// Application-level configuration for 1 Minute Ludo.
///
/// Change [apiBaseUrl] and [socketUrl] to match the target environment
/// before building a release.
class AppConfig {
  AppConfig._();

  // ─── Environment ────────────────────────────────────────────────────────────

  /// Set to `false` before building a production release.
  static const bool isDevelopment = true;

  // ─── Backend ────────────────────────────────────────────────────────────────

  /// REST API base URL.
  /// `10.0.2.2` routes to the host machine from an Android emulator.
  /// Replace with your server's IP or domain for physical device / production.
  static const String apiBaseUrl = 'http://10.0.2.2:5000/api';

  /// Socket.IO server URL.
  static const String socketUrl = 'http://10.0.2.2:5000';

  // ─── Timeouts ───────────────────────────────────────────────────────────────

  /// Default HTTP request timeout.
  static const Duration httpTimeout = Duration(seconds: 15);
}
