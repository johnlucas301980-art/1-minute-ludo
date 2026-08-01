import '../../../core/network/api_client.dart';
import '../models/active_match_result.dart';

/// Checks whether the authenticated player has an active resumable match.
///
/// Usage:
/// ```dart
/// final result = await activeMatchService.checkActiveMatch();
/// if (result.hasActiveMatch) { ... }
/// ```
class ActiveMatchService {
  ActiveMatchService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Calls GET /api/game/active-match.
  ///
  /// Returns [ActiveMatchResult] with [hasActiveMatch] == false on any error
  /// so callers can always proceed normally when the check fails.
  Future<ActiveMatchResult> checkActiveMatch() async {
    try {
      final json = await _api.authenticatedRequest('GET', '/game/active-match');
      return ActiveMatchResult.fromJson(json);
    } catch (_) {
      return const ActiveMatchResult(hasActiveMatch: false);
    }
  }
}
