import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';

/// Provides the three-step password reset flow for 1 Minute Ludo.
///
/// Step 1 — [requestOtp]:   user submits email → backend sends a 6-digit OTP.
/// Step 2 — [verifyOtp]:   user submits email + OTP → backend returns a reset token.
/// Step 3 — [confirmReset]: user submits reset token + new password → password updated.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage = TokenStorage();
/// final client  = ApiClient(tokenStorage: storage);
/// final reset   = PasswordResetService(apiClient: client);
/// ```
class PasswordResetService {
  PasswordResetService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Step 1: Request OTP ─────────────────────────────────────────────────────

  /// Requests a 6-digit OTP to be sent to [email].
  ///
  /// The server always returns success to prevent account enumeration, so this
  /// method returns void regardless of whether the email is registered.
  ///
  /// Throws [ApiException] on validation errors (400) or rate-limit (429).
  Future<void> requestOtp({required String email}) async {
    await _api.publicRequest(
      'POST',
      '/auth/password-reset/request',
      body: {'email': email},
    );
  }

  // ─── Step 2: Verify OTP ──────────────────────────────────────────────────────

  /// Verifies [otp] for the given [email] and returns a short-lived reset token.
  ///
  /// Throws [OtpExpiredException] when the OTP has expired or is no longer valid.
  /// Throws [ApiException] on incorrect OTP (400) or too many attempts (400).
  Future<String> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final json = await _api.publicRequest(
        'POST',
        '/auth/password-reset/verify',
        body: {'email': email, 'otp': otp},
      );
      return (json['data'] as Map<String, dynamic>)['reset_token'] as String;
    } on ApiException catch (e) {
      // Surface expiry as a dedicated exception so the UI can prompt for a new OTP.
      if (e.statusCode == 400 &&
          (e.message.contains('expired') || e.message.contains('invalid'))) {
        throw OtpExpiredException(message: e.message);
      }
      rethrow;
    }
  }

  // ─── Step 3: Confirm new password ────────────────────────────────────────────

  /// Applies the new password using [resetToken] (obtained from [verifyOtp]).
  ///
  /// On success all existing sessions for the account are invalidated server-side.
  ///
  /// Throws [OtpExpiredException] when the reset session is no longer valid.
  /// Throws [ApiException] on validation errors (400) or expired token (401).
  Future<void> confirmReset({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _api.publicRequest(
        'POST',
        '/auth/password-reset/confirm',
        body: {
          'reset_token': resetToken,
          'new_password': newPassword,
        },
      );
    } on ApiException catch (e) {
      if (e.statusCode == 400 && e.message.contains('no longer valid')) {
        throw OtpExpiredException(message: e.message);
      }
      rethrow;
    }
  }
}
