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
