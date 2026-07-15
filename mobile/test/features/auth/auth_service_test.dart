import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/services/auth_service.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json'});
}

final _profileJson = {
  'id': 'user-uuid-1',
  'player_id': 'LUD-ABC123',
  'full_name': 'Test Player',
  'email': 'test@example.com',
  'mobile': null,
  'country': 'NG',
  'avatar': null,
  'status': 'active',
  'created_at': '2026-07-15T00:00:00.000Z',
};

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late AuthService authService;

  void buildServices(http.Client mockHttpClient) {
    tokenStorage = const TokenStorage();
    apiClient = ApiClient(tokenStorage: tokenStorage, httpClient: mockHttpClient);
    authService = AuthService(apiClient: apiClient, tokenStorage: tokenStorage);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  // ─── Register ──────────────────────────────────────────────────────────────

  group('AuthService.register', () {
    test('returns UserProfile on success', () async {
      buildServices(MockClient((_) async => _jsonResponse({
            'success': true,
            'data': _profileJson,
          })));

      final profile = await authService.register(
        fullName: 'Test Player',
        email: 'test@example.com',
        password: 'Secret123',
      );

      expect(profile.playerId, 'LUD-ABC123');
      expect(profile.fullName, 'Test Player');
      expect(profile.status, 'active');
    });

    test('throws ApiException on 409 duplicate', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Email already registered.'},
            status: 409,
          )));

      await expectLater(
        () => authService.register(
          fullName: 'Test Player',
          email: 'test@example.com',
          password: 'Secret123',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  // ─── Login ─────────────────────────────────────────────────────────────────

  group('AuthService.login', () {
    test('stores tokens and returns UserProfile on success', () async {
      buildServices(MockClient((_) async => _jsonResponse({
            'success': true,
            'data': {
              'access_token': 'acc-token-123',
              'refresh_token': 'ref-token-456',
              'profile': _profileJson,
            },
          })));

      final profile = await authService.login(
        identifier: 'test@example.com',
        password: 'Secret123',
      );

      expect(profile.playerId, 'LUD-ABC123');
      // Tokens must be persisted securely.
      expect(await tokenStorage.getAccessToken(), 'acc-token-123');
      expect(await tokenStorage.getRefreshToken(), 'ref-token-456');
    });

    test('throws ApiException on 401 invalid credentials', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Invalid credentials.'},
            status: 401,
          )));

      await expectLater(
        () => authService.login(
          identifier: 'bad@example.com',
          password: 'wrong',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('throws AccountForbiddenException on 403 suspended account', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Your account has been suspended.'},
            status: 403,
          )));

      await expectLater(
        () => authService.login(
          identifier: 'banned@example.com',
          password: 'Secret123',
        ),
        throwsA(isA<AccountForbiddenException>()),
      );
    });
  });

  // ─── Logout ────────────────────────────────────────────────────────────────

  group('AuthService.logout', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('clears tokens after successful single-device logout', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'acc-token-123',
        'ludo_refresh_token': 'ref-token-456',
      });
      tokenStorage = const TokenStorage();
      apiClient = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((_) async =>
            _jsonResponse({'success': true, 'message': 'Logged out successfully.'})),
      );
      authService = AuthService(apiClient: apiClient, tokenStorage: tokenStorage);

      await authService.logout();

      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test('clears tokens even when server call fails', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'acc-token-123',
        'ludo_refresh_token': 'ref-token-456',
      });
      tokenStorage = const TokenStorage();
      apiClient = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((req) async {
          // /auth/refresh returns 401 so the authenticated request gives up
          if (req.url.path.endsWith('/auth/refresh')) {
            return _jsonResponse(
                {'success': false, 'message': 'Expired.'}, status: 401);
          }
          return _jsonResponse(
              {'success': false, 'message': 'Server error.'}, status: 500);
        }),
      );
      authService = AuthService(apiClient: apiClient, tokenStorage: tokenStorage);

      // Logout must not throw — it always clears storage.
      await authService.logout();

      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test('isLoggedIn returns false after logout', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'acc-token-123',
        'ludo_refresh_token': 'ref-token-456',
      });
      tokenStorage = const TokenStorage();
      apiClient = ApiClient(
        tokenStorage: tokenStorage,
        httpClient: MockClient((_) async =>
            _jsonResponse({'success': true, 'message': 'Logged out successfully.'})),
      );
      authService = AuthService(apiClient: apiClient, tokenStorage: tokenStorage);

      expect(await authService.isLoggedIn(), isTrue);
      await authService.logout();
      expect(await authService.isLoggedIn(), isFalse);
    });
  });

  // ─── isLoggedIn ────────────────────────────────────────────────────────────

  group('AuthService.isLoggedIn', () {
    test('returns false when no token is stored', () async {
      buildServices(MockClient((_) async => throw UnimplementedError()));
      expect(await authService.isLoggedIn(), isFalse);
    });

    test('returns true when access token is present', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'some-token',
      });
      buildServices(MockClient((_) async => throw UnimplementedError()));
      expect(await authService.isLoggedIn(), isTrue);
    });
  });
}
