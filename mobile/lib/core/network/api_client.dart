import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../storage/token_storage.dart';

/// Low-level HTTP client for the 1 Minute Ludo backend.
///
/// Two request modes:
/// - [publicRequest]        — no auth header (login, register, refresh)
/// - [authenticatedRequest] — attaches Bearer token; silently refreshes once
///                            on 401 before giving up.
///
/// Tokens are never written to logs.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    http.Client? httpClient,
  })  : _tokenStorage = tokenStorage,
        _httpClient = httpClient ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _httpClient;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Sends a request without an Authorization header.
  /// Use for login, register, and refresh endpoints.
  Future<Map<String, dynamic>> publicRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(method, path, body: body);
    return _decode(response);
  }

  /// Sends an authenticated request with a Bearer access token.
  ///
  /// On a 401 response, attempts a silent token refresh exactly once.
  /// If the refresh succeeds, retries the original request with the new token.
  /// If the refresh fails, clears all stored tokens and throws
  /// [SessionExpiredException].
  ///
  /// **[domainRejectionPattern]** — optional substring to match against the
  /// server's 401 response body `message` field.  Use this for endpoints where
  /// a 401 can mean a domain-level rejection (e.g. "Current password is
  /// incorrect") rather than token expiry.  When the first 401 body message
  /// contains [domainRejectionPattern], the response is decoded directly as an
  /// [ApiException] with no refresh attempt and no token clearing — the session
  /// remains valid.  When the message does *not* match (genuine token-expiry
  /// 401), the normal refresh-and-retry flow proceeds unchanged.
  /// Defaults to `null`; all existing callers are completely unaffected.
  Future<Map<String, dynamic>> authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? domainRejectionPattern,
  }) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      await _tokenStorage.clearAll();
      throw SessionExpiredException();
    }

    final response = await _send(method, path, body: body, accessToken: accessToken);

    if (response.statusCode == 401) {
      // ── Domain-level 401 detection ─────────────────────────────────────────
      // If the caller provided a pattern and the server's message matches it,
      // this is a domain rejection (e.g. wrong current password), not a
      // token-expiry event.  Surface it as ApiException directly — no refresh,
      // no token clearing; the player's session remains intact.
      //
      // The JSON parsing is isolated in its own try-catch so that the
      // ApiException thrown by _decode propagates freely if the pattern matches.
      if (domainRejectionPattern != null) {
        var isDomainRejection = false;
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final message = decoded['message'] as String? ?? '';
          isDomainRejection = message.contains(domainRejectionPattern);
        } catch (_) {
          // Malformed body — fall through to the standard refresh path.
        }
        if (isDomainRejection) {
          return _decode(response); // throws ApiException(401, serverMessage)
        }
      }

      // ── One refresh attempt ────────────────────────────────────────────────
      final newAccessToken = await _attemptRefresh();
      if (newAccessToken == null) {
        await _tokenStorage.clearAll();
        throw SessionExpiredException();
      }

      // ── One retry (no further refresh on second 401) ───────────────────────
      final retried = await _send(method, path, body: body, accessToken: newAccessToken);
      if (retried.statusCode == 401) {
        await _tokenStorage.clearAll();
        throw SessionExpiredException();
      }
      return _decode(retried);
    }

    return _decode(response);
  }

  // ─── Internals ──────────────────────────────────────────────────────────────

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final encodedBody = body != null ? jsonEncode(body) : null;

    late http.Response response;

    switch (method.toUpperCase()) {
      case 'POST':
        response = await _httpClient
            .post(uri, headers: headers, body: encodedBody)
            .timeout(AppConfig.httpTimeout);
      case 'GET':
        response = await _httpClient
            .get(uri, headers: headers)
            .timeout(AppConfig.httpTimeout);
      case 'PUT':
        response = await _httpClient
            .put(uri, headers: headers, body: encodedBody)
            .timeout(AppConfig.httpTimeout);
      case 'DELETE':
        response = await _httpClient
            .delete(uri, headers: headers, body: encodedBody)
            .timeout(AppConfig.httpTimeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    return response;
  }

  /// Calls POST /auth/refresh using the stored refresh token.
  /// Saves the new access token on success. Returns null on any failure.
  /// Tokens are never logged.
  Future<String?> _attemptRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _send(
        'POST',
        '/auth/refresh',
        body: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken =
            (data['data'] as Map<String, dynamic>)['access_token'] as String;
        await _tokenStorage.saveAccessToken(newAccessToken);
        return newAccessToken;
      }
    } catch (_) {
      // Any failure here means the refresh token is unusable.
    }
    return null;
  }

  /// Decodes a response and returns the JSON body, or throws the appropriate
  /// [ApiException] subclass on non-2xx status codes.
  Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Invalid response from server.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final message =
        json['message'] as String? ?? 'Unexpected error (${response.statusCode}).';

    if (response.statusCode == 403) {
      throw AccountForbiddenException(message: message);
    }

    throw ApiException(statusCode: response.statusCode, message: message);
  }
}
