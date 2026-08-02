import '../../../core/network/api_client.dart';
import '../models/login_history_entry.dart';

/// Provides login history operations for the 1 Minute Ludo app.
///
/// All dependencies are injected through the constructor — no singletons.
class LoginHistoryService {
  LoginHistoryService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Get Login History ───────────────────────────────────────────────────────

  /// Fetches the authenticated player's login history, ordered newest first.
  ///
  /// Throws [ApiException] on non-2xx responses.
  /// Throws [SessionExpiredException] when the token refresh also fails.
  Future<List<LoginHistoryEntry>> getLoginHistory() async {
    final json = await _api.authenticatedRequest('GET', '/auth/login-history');
    final data = json['data'] as List<dynamic>;
    return data
        .map((e) => LoginHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
