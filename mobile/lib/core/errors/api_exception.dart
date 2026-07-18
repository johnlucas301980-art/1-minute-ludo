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
