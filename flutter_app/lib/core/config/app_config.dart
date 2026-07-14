/// Application-level configuration for 1 Minute Ludo.
///
/// Base URLs and connection settings are defined here so they can be
/// swapped per environment (development, staging, production) from one place.
class AppConfig {
  AppConfig._();

  // ─── Environment flags ──────────────────────────────────────────────────────

  /// Set to `false` before building a production release.
  static const bool isDevelopment = true;

  // ─── API ────────────────────────────────────────────────────────────────────

  /// Base URL for REST API requests.
  /// Change this to the production domain before release.
  static const String apiBaseUrl = 'http://10.0.2.2:5000/api';

  // ─── Socket.IO ──────────────────────────────────────────────────────────────

  /// WebSocket server URL.
  /// `10.0.2.2` routes to the host machine from an Android emulator.
  static const String socketUrl = 'http://10.0.2.2:5000';

  // ─── Timeouts ───────────────────────────────────────────────────────────────

  /// Default HTTP request timeout.
  static const Duration httpTimeout = Duration(seconds: 15);

  /// Socket.IO reconnection delay.
  static const Duration socketReconnectDelay = Duration(seconds: 3);
}
