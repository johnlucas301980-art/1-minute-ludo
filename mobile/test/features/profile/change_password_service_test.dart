import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/profile/services/change_password_service.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// 200 success body as returned by PUT /profile/password.
http.Response _successResponse() => _jsonResponse(
      {'success': true, 'message': 'Password changed successfully.'},
    );

/// 401 body returned when the current password does not match.
http.Response _wrongPasswordResponse() => _jsonResponse(
      {'success': false, 'message': 'Current password is incorrect.'},
      status: 401,
    );

/// 400 validation failure body.
http.Response _validationErrorResponse({
  String field = 'new_password',
  String message = 'New password must be at least 8 characters.',
}) =>
    _jsonResponse(
      {
        'success': false,
        'message': 'Validation failed.',
        'errors': [
          {'field': field, 'message': message},
        ],
      },
      status: 400,
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late ChangePasswordService changePasswordService;

  void buildServices(http.Client mockHttpClient) {
    tokenStorage = const TokenStorage();
    apiClient =
        ApiClient(tokenStorage: tokenStorage, httpClient: mockHttpClient);
    changePasswordService = ChangePasswordService(apiClient: apiClient);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ─── Happy path ─────────────────────────────────────────────────────────────

  group('ChangePasswordService.changePassword — happy path', () {
    test('1 — successful change completes without exception', () async {
      buildServices(MockClient((_) async => _successResponse()));

      // Should complete with no exception (returns void).
      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'OldPass1',
          newPassword: 'NewPass2',
        ),
        returnsNormally,
      );
    });

    test('2 — sends correct body keys to PUT /profile/password', () async {
      Map<String, dynamic>? capturedBody;

      buildServices(MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _successResponse();
      }));

      await changePasswordService.changePassword(
        currentPassword: 'OldPass1',
        newPassword: 'NewPass2',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['current_password'], 'OldPass1');
      expect(capturedBody!['new_password'], 'NewPass2');
    });

    test(
        '3 — expired access token: refresh succeeds, retry succeeds, '
        'new token stored', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-access-token',
        'ludo_refresh_token': 'valid-refresh-token',
      });

      var passwordCallCount = 0;

      buildServices(MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse({
            'success': true,
            'data': {'access_token': 'new-access-token'},
          });
        }
        passwordCallCount++;
        if (passwordCallCount == 1) {
          // First attempt — expired access token
          return _jsonResponse(
            {'success': false, 'message': 'Access token expired.'},
            status: 401,
          );
        }
        // Retry after successful refresh
        return _successResponse();
      }));

      await changePasswordService.changePassword(
        currentPassword: 'OldPass1',
        newPassword: 'NewPass2',
      );

      // Confirm the request was retried after refresh
      expect(passwordCallCount, 2);
      // New access token must be persisted
      expect(await tokenStorage.getAccessToken(), 'new-access-token');
    });
  });

  // ─── Wrong current password ─────────────────────────────────────────────────

  group('ChangePasswordService.changePassword — wrong current password', () {
    test(
        '4 — server returns 401 "Current password is incorrect." → '
        'throws WrongCurrentPasswordException', () async {
      buildServices(MockClient((_) async => _wrongPasswordResponse()));

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'WrongPass1',
          newPassword: 'NewPass2',
        ),
        throwsA(isA<WrongCurrentPasswordException>()),
      );
    });

    test(
        '5 — WrongCurrentPasswordException is an ApiException subclass '
        'with statusCode 401', () async {
      buildServices(MockClient((_) async => _wrongPasswordResponse()));

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'WrongPass1',
          newPassword: 'NewPass2',
        ),
        throwsA(
          isA<WrongCurrentPasswordException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e, 'is ApiException', isA<ApiException>()),
        ),
      );
    });
  });

  // ─── Validation and server errors ───────────────────────────────────────────

  group('ChangePasswordService.changePassword — validation & server errors', () {
    test('6 — server returns 400 validation failure → throws ApiException 400',
        () async {
      buildServices(MockClient((_) async => _validationErrorResponse()));

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'OldPass1',
          newPassword: 'short',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('7 — ApiException(400) carries the server-provided message', () async {
      const serverMessage = 'Validation failed.';
      buildServices(MockClient((_) async => _validationErrorResponse()));

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'OldPass1',
          newPassword: 'short',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', serverMessage),
        ),
      );
    });

    test('8 — server returns 500 → throws ApiException 500', () async {
      buildServices(
        MockClient((_) async => _jsonResponse(
              {
                'success': false,
                'message': 'An unexpected error occurred. Please try again.',
              },
              status: 500,
            )),
      );

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'OldPass1',
          newPassword: 'NewPass2',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  // ─── Session and network errors ─────────────────────────────────────────────

  group('ChangePasswordService.changePassword — session & network errors', () {
    test('9 — no access token stored → throws SessionExpiredException',
        () async {
      // Clear all tokens so ApiClient has nothing to send
      FlutterSecureStorage.setMockInitialValues({});

      buildServices(MockClient((_) async => _successResponse()));

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'OldPass1',
          newPassword: 'NewPass2',
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test(
        '10 — expired access token AND expired refresh token → '
        'throws SessionExpiredException', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-access-token',
        'ludo_refresh_token': 'expired-refresh-token',
      });

      buildServices(MockClient((req) async {
        // Both the password endpoint and the refresh endpoint reject with 401
        return _jsonResponse(
          {'success': false, 'message': 'Token expired.'},
          status: 401,
        );
      }));

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'OldPass1',
          newPassword: 'NewPass2',
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('11 — network timeout / unreachable → throws Exception', () async {
      buildServices(
        MockClient((_) async => throw Exception('Network unreachable')),
      );

      await expectLater(
        () => changePasswordService.changePassword(
          currentPassword: 'OldPass1',
          newPassword: 'NewPass2',
        ),
        throwsException,
      );
    });
  });
}
