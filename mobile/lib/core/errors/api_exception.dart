/// Thrown when the backend returns a non-success response.
class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when an authenticated request receives a 401 and the subsequent
/// token refresh also fails.  The UI layer should clear state and navigate
/// the user back to the login screen.
class SessionExpiredException extends ApiException {
  SessionExpiredException()
      : super(statusCode: 401, message: 'Session expired. Please log in again.');
}

/// Thrown when the server returns a 403 (suspended / banned account).
class AccountForbiddenException extends ApiException {
  const AccountForbiddenException({required super.message})
      : super(statusCode: 403);
}

/// Thrown when a password reset OTP (or the reset session derived from it)
/// is expired or no longer valid.  The UI layer should prompt the user to
/// request a new OTP rather than retry the same one.
class OtpExpiredException extends ApiException {
  OtpExpiredException({String? message})
      : super(
          statusCode: 400,
          message: message ?? 'OTP has expired. Please request a new one.',
        );
}

/// Thrown by [ChangePasswordService] when the backend rejects the supplied
/// current password.  The UI layer should highlight the current-password
/// field and prompt the user to try again — the session remains active and
/// tokens are NOT cleared.
class WrongCurrentPasswordException extends ApiException {
  WrongCurrentPasswordException()
      : super(statusCode: 401, message: 'Current password is incorrect.');
}

/// Thrown by [PaymentService.withdraw] when the player's wallet balance is
/// insufficient to cover the requested withdrawal amount (HTTP 422).
///
/// The UI layer should surface a balance error message — this is a domain
/// rejection, not a session event.  Tokens are NOT cleared.
class InsufficientBalanceException extends ApiException {
  InsufficientBalanceException({String? message})
      : super(
          statusCode: 422,
          message: message ?? 'Insufficient balance.',
        );
}

/// Thrown when the backend returns a `403` with `code: "COUNTRY_BLOCKED"`.
///
/// The UI layer should show the exact server message rather than a generic
/// error.  Registration, login, and gameplay are all blocked.
class CountryBlockedException extends ApiException {
  const CountryBlockedException({required super.message})
      : super(statusCode: 403);
}

/// Thrown when the backend returns a `400` with an `errors` array containing
/// field-level validation messages.
///
/// The UI layer should map each entry to the corresponding form field and
/// display the message directly below that field (red border, inline text).
/// This exception must NOT trigger a Snackbar.
class FieldValidationException extends ApiException {
  FieldValidationException({
    required this.fieldErrors,
    String? fallbackMessage,
  }) : super(
          statusCode: 400,
          message: fallbackMessage ??
              (fieldErrors.values.isNotEmpty
                  ? fieldErrors.values.first
                  : 'Validation failed.'),
        );

  /// Map of field name → human-readable error message.
  ///
  /// Keys match the field names used in the backend error array (e.g.
  /// `"full_name"`, `"email"`, `"mobile"`, `"password"`).
  final Map<String, String> fieldErrors;
}
