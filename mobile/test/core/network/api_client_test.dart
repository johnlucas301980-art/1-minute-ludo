import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json'});
}

Map<String, dynamic> _successBody([Map<String, dynamic>? data]) =>
    {'success': true, 'data': data ?? {}};

Map<String, dynamic> _errorBody(String message) =>
    {'success': false, 'message': message};

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage tokenStorage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tokenStorage = const TokenStorage();
  });

  group('ApiClient.publicRequest', () {
    test('returns decoded JSON on 200', () async {
      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((_) async =>
            _jsonResponse(_successBody({'key': 'value'}))),
      );
      final result = await client.publicRequest('POST', '/auth/login');
      expect(result['data'], {'key': 'value'});
    });

    test('throws ApiException on 400', () async {
      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((_) async =>
            _jsonResponse(_errorBody('Bad request.'), status: 400)),
      );
      expect(
        () => client.publicRequest('POST', '/auth/register'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'Bad request.')),
      );
    });

    test('throws AccountForbiddenException on 403', () async {
      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((_) async =>
            _jsonResponse(_errorBody('Account suspended.'), status: 403)),
      );
      expect(
        () => client.publicRequest('POST', '/auth/login'),
        throwsA(isA<AccountForbiddenException>()),
      );
    });
  });

  group('ApiClient.authenticatedRequest', () {
    test('attaches Bearer token and returns JSON on 200', () async {
      await tokenStorage.saveTokens(
        accessToken: 'valid-access',
        refreshToken: 'valid-refresh',
      );

      String? capturedAuth;
      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((req) async {
          capturedAuth = req.headers['authorization'];
          return _jsonResponse(_successBody({'ok': true}));
        }),
      );

      final result =
          await client.authenticatedRequest('GET', '/protected');
      expect(capturedAuth, 'Bearer valid-access');
      expect(result['data'], {'ok': true});
    });

    test('refreshes token on 401 and retries once', () async {
      await tokenStorage.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'valid-refresh',
      );

      int callCount = 0;
      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((req) async {
          callCount++;
          // First call → 401 (triggers refresh)
          if (req.url.path.endsWith('/protected') && callCount == 1) {
            return _jsonResponse({'success': false, 'message': 'Expired.'}, status: 401);
          }
          // Refresh call → 200 with new access token
          if (req.url.path.endsWith('/auth/refresh')) {
            return _jsonResponse(_successBody({'access_token': 'new-access'}));
          }
          // Retry call → 200
          return _jsonResponse(_successBody({'retried': true}));
        }),
      );

      final result = await client.authenticatedRequest('GET', '/protected');
      expect(result['data'], {'retried': true});
      // New access token must be persisted.
      expect(await tokenStorage.getAccessToken(), 'new-access');
    });

    test('throws SessionExpiredException when refresh fails', () async {
      await tokenStorage.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'expired-refresh',
      );

      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/auth/refresh')) {
            return _jsonResponse({'success': false, 'message': 'Expired.'}, status: 401);
          }
          return _jsonResponse({'success': false, 'message': 'Expired.'}, status: 401);
        }),
      );

      await expectLater(
        () => client.authenticatedRequest('GET', '/protected'),
        throwsA(isA<SessionExpiredException>()),
      );
      // Tokens must be cleared after session expiry.
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test('throws SessionExpiredException when no access token is stored', () async {
      // Storage starts empty (no tokens).
      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((_) async => _jsonResponse(_successBody())),
      );
      expect(
        () => client.authenticatedRequest('GET', '/protected'),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('does not retry more than once after refresh', () async {
      await tokenStorage.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'valid-refresh',
      );

      int protectedCallCount = 0;
      final client = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/auth/refresh')) {
            return _jsonResponse(_successBody({'access_token': 'new-access'}));
          }
          protectedCallCount++;
          // Always return 401 for /protected to confirm no 3rd call is made.
          return _jsonResponse({'success': false, 'message': 'Expired.'}, status: 401);
        }),
      );

      await expectLater(
        () => client.authenticatedRequest('GET', '/protected'),
        throwsA(isA<SessionExpiredException>()),
      );
      // Called exactly twice: original + one retry.
      expect(protectedCallCount, 2);
    });
  });
}
