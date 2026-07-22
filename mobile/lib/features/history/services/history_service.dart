import '../../../core/network/api_client.dart';
import '../models/match_history.dart';

/// Provides match history operations for the 1 Minute Ludo app.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage = TokenStorage();
/// final client  = ApiClient(tokenStorage: storage);
/// final history = HistoryService(apiClient: client);
///
/// try {
///   final page = await history.getHistory(limit: 20, offset: 0);
///   // page.entries — list of completed matches
///   // page.total   — total matches available across all pages
/// } on SessionExpiredException {
///   // navigate to login
/// } on ApiException catch (e) {
///   // surface e.message
/// }
/// ```
class HistoryService {
  HistoryService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Get History ─────────────────────────────────────────────────────────────

  /// Fetches a paginated page of the authenticated player's completed matches,
  /// ordered newest first.
  ///
  /// [limit] controls how many records to return (the backend enforces 1–100;
  /// values outside that range return a 400 error). Defaults to 20 to match
  /// the backend default.
  ///
  /// [offset] is the number of records to skip for pagination. Defaults to 0.
  ///
  /// Returns a [MatchHistory] containing the match entries and pagination
  /// metadata from GET /api/match/history.
  ///
  /// Throws [ApiException] on non-2xx responses (including 400 for invalid
  /// limit/offset values).
  /// Throws [SessionExpiredException] when the token refresh also fails.
  Future<MatchHistory> getHistory({
    int limit  = 20,
    int offset = 0,
  }) async {
    final json = await _api.authenticatedRequest(
      'GET',
      '/match/history?limit=$limit&offset=$offset',
    );
    final data = json['data'] as Map<String, dynamic>;
    return MatchHistory.fromJson(data);
  }
}
