import '../../../core/network/api_client.dart';
import '../models/leaderboard.dart';

// ---------------------------------------------------------------------------
// LeaderboardService
// ---------------------------------------------------------------------------

/// Provides leaderboard operations for the 1 Minute Ludo app.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage     = TokenStorage();
/// final client      = ApiClient(tokenStorage: storage);
/// final leaderboard = LeaderboardService(apiClient: client);
///
/// try {
///   final board = await leaderboard.getLeaderboard();
///   // board.entries — ranked list of players
/// } on SessionExpiredException {
///   // navigate to login
/// } on ApiException catch (e) {
///   // surface e.message
/// }
/// ```
class LeaderboardService {
  LeaderboardService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Get Leaderboard ─────────────────────────────────────────────────────────

  /// Fetches the global leaderboard from the backend.
  ///
  /// Returns a [Leaderboard] containing all players ranked by wins descending,
  /// then full_name ascending. The list is empty when no players exist.
  ///
  /// Throws [ApiException] on non-2xx responses.
  /// Throws [SessionExpiredException] when the token refresh also fails.
  Future<Leaderboard> getLeaderboard() async {
    final json = await _api.authenticatedRequest('GET', '/leaderboard');
    final data = json['data'] as Map<String, dynamic>;
    return Leaderboard.fromJson(data);
  }
}
