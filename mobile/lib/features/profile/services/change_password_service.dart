import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';

/// Provides the change-password operation for authenticated players.
///
/// Wraps PUT /api/profile/password.  The backend verifies the current
/// password, hashes the new one, and revokes all existing refresh tokens
/// so that other devices are signed out immediately.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage  = TokenStorage();
/// final client   = ApiClient(tokenStorage: storage);
/// final service  = ChangePasswordService(apiClient: client);
///
/// try {
///   await service.changePassword(
///     currentPassword: 'OldPass1',
///     newPassword:     'NewPass2',
///   );
///   // success — navigate away or show confirmation
/// } on WrongCurrentPasswordException {
///   // highlight the current-password field
/// } on SessionExpiredException {
///   // clear local state and navigate to login
/// } on ApiException catch (e) {
///   // surface e.message (validation error, server error, etc.)
/// }
/// ```
class ChangePasswordService {
  ChangePasswordService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Change Password ─────────────────────────────────────────────────────────

  /// Changes the authenticated player's password.
  ///
  /// Sends [currentPassword] and [newPassword] to PUT /api/profile/password.
  /// On success the server revokes all refresh tokens, ending all other active
  /// sessions for this account.
  ///
  /// **[bypassRefreshOn401]** is set to `true` on the underlying
  /// [ApiClient.authenticatedRequest] call so that a 401 "Current password is
  /// incorrect" response is not misinterpreted as a token-expiry event and
  /// does not clear the player's stored tokens.
  ///
  /// Throws [WrongCurrentPasswordException] when the current password is wrong.
  /// Throws [ApiException] on validation failures (400) or server errors (5xx).
  /// Throws [SessionExpiredException] when the access token is absent or the
  /// refresh token is expired (genuine session expiry, not wrong password).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.authenticatedRequest(
        'PUT',
        '/profile/password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        // A 401 with this message is a domain rejection (wrong password), not
        // token expiry. The ApiClient will surface it as ApiException(401)
        // without attempting a refresh or clearing the player's tokens.
        domainRejectionPattern: 'Current password is incorrect',
      );
    } on ApiException catch (e) {
      // Map the domain-level 401 to a dedicated exception so the UI can
      // highlight the current-password field without treating the event as
      // a session expiry.  All other ApiExceptions propagate unchanged.
      if (e.statusCode == 401 &&
          e.message.contains('Current password is incorrect')) {
        throw WrongCurrentPasswordException();
      }
      rethrow;
    }
  }
}
