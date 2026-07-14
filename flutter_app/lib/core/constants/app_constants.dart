/// Application-wide constants for 1 Minute Ludo.
class AppConstants {
  AppConstants._();

  // ─── App identity ────────────────────────────────────────────────────────────

  static const String appName = '1 Minute Ludo';
  static const String packageName = 'com.minuteludo.app';

  // ─── Game rules ─────────────────────────────────────────────────────────────

  /// Duration of a single match in seconds.
  static const int matchDurationSeconds = 60;

  /// Number of players in one game.
  static const int playersPerGame = 4;

  /// Number of tokens per player.
  static const int tokensPerPlayer = 4;

  // ─── Storage keys ────────────────────────────────────────────────────────────

  /// Secure storage key for the auth token.
  static const String keyAuthToken = 'auth_token';

  /// Secure storage key for the user profile.
  static const String keyUserProfile = 'user_profile';
}
