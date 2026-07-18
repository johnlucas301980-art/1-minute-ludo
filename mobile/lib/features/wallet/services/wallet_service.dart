import '../../../core/network/api_client.dart';
import '../models/wallet.dart';

// ---------------------------------------------------------------------------
// WalletService
// ---------------------------------------------------------------------------

/// Provides wallet operations for the 1 Minute Ludo app.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage = TokenStorage();
/// final client  = ApiClient(tokenStorage: storage);
/// final wallet  = WalletService(apiClient: client);
/// ```
class WalletService {
  WalletService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Get Wallet ──────────────────────────────────────────────────────────────

  /// Fetches the authenticated player's wallet balance from the backend.
  ///
  /// A wallet is created automatically on first access — no prior setup is
  /// required.  Returns a [Wallet] populated from GET /api/wallet.
  ///
  /// Throws [ApiException] on non-2xx responses.
  /// Throws [SessionExpiredException] when the token refresh also fails.
  Future<Wallet> getWallet() async {
    final json = await _api.authenticatedRequest('GET', '/wallet');
    final data = json['data'] as Map<String, dynamic>;
    return Wallet.fromJson(data['wallet'] as Map<String, dynamic>);
  }

  // ─── Get History ─────────────────────────────────────────────────────────────

  /// Fetches a paginated list of the player's wallet transactions, newest first.
  ///
  /// [limit] controls how many records to return (the backend accepts 1–100;
  /// values outside that range are silently clamped server-side).  Defaults to
  /// `20` to match the backend default.
  ///
  /// [offset] is the number of records to skip for pagination.  Defaults to `0`.
  ///
  /// Returns a [WalletHistory] containing the transactions and pagination
  /// metadata from GET /api/wallet/history.
  ///
  /// Throws [ApiException] on non-2xx responses.
  /// Throws [SessionExpiredException] when the token refresh also fails.
  Future<WalletHistory> getHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final json = await _api.authenticatedRequest(
      'GET',
      '/wallet/history?limit=$limit&offset=$offset',
    );
    final data = json['data'] as Map<String, dynamic>;
    return WalletHistory.fromJson(data);
  }
}
