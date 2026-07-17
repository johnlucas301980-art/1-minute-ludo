import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/profile/services/profile_service.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Full profile JSON as returned by GET /profile and PUT /profile.
/// Includes updated_at, which auth responses do not carry.
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
  'updated_at': '2026-07-17T00:00:00.000Z',
};

http.Response _profileResponse({Map<String, dynamic>? overrides}) {
  final profile = {..._profileJson, ...?overrides};
  return _jsonResponse({'success': true, 'data': {'profile': profile}});
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late ProfileService profileService;

  void buildServices(http.Client mockHttpClient) {
    tokenStorage = const TokenStorage();
    apiClient = ApiClient(tokenStorage: tokenStorage, httpClient: mockHttpClient);
    profileService = ProfileService(apiClient: apiClient);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ─── getProfile ────────────────────────────────────────────────────────────

  group('ProfileService.getProfile', () {
    test('1 — returns UserProfile with all fields on success', () async {
      buildServices(MockClient((_) async => _profileResponse()));

      final profile = await profileService.getProfile();

      expect(profile.playerId, 'LUD-ABC123');
      expect(profile.fullName, 'Test Player');
      expect(profile.email, 'test@example.com');
      expect(profile.country, 'NG');
      expect(profile.avatar, isNull);
      expect(profile.status, 'active');
      expect(profile.updatedAt, '2026-07-17T00:00:00.000Z');
    });

    test('2 — throws ApiException on 401', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Access token expired.'},
            status: 401,
          )));

      await expectLater(
        () => profileService.getProfile(),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('3 — throws ApiException on 500 server error', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {'success': false, 'message': 'Internal server error.'},
            status: 500,
          )));

      await expectLater(
        () => profileService.getProfile(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('4 — retries with refreshed token after 401', () async {
      // Simulate an expired access token: first profile call → 401,
      // then ApiClient silently refreshes, then retries → 200.
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-access-token',
        'ludo_refresh_token': 'valid-refresh-token',
      });

      var profileCallCount = 0;
      buildServices(MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse({
            'success': true,
            'data': {'access_token': 'new-access-token'},
          });
        }
        profileCallCount++;
        if (profileCallCount == 1) {
          // First attempt — expired token
          return _jsonResponse(
            {'success': false, 'message': 'Access token expired.'},
            status: 401,
          );
        }
        // Retry after refresh — success
        return _profileResponse();
      }));

      final profile = await profileService.getProfile();

      expect(profile.playerId, 'LUD-ABC123');
      // Confirm a retry happened
      expect(profileCallCount, 2);
      // New access token must be stored
      expect(await tokenStorage.getAccessToken(), 'new-access-token');
    });

    test('5 — throws Exception on network timeout / offline', () async {
      buildServices(
        MockClient((_) async => throw Exception('Network unreachable')),
      );

      await expectLater(
        () => profileService.getProfile(),
        throwsException,
      );
    });
  });

  // ─── updateProfile ─────────────────────────────────────────────────────────

  group('ProfileService.updateProfile', () {
    test('6 — updates fullName and returns updated UserProfile', () async {
      buildServices(MockClient((_) async =>
          _profileResponse(overrides: {'full_name': 'Updated Name'})));

      final profile = await profileService.updateProfile(fullName: 'Updated Name');

      expect(profile.fullName, 'Updated Name');
    });

    test('7 — updates country and returns updated UserProfile', () async {
      buildServices(MockClient((_) async =>
          _profileResponse(overrides: {'country': 'Nigeria'})));

      final profile = await profileService.updateProfile(country: 'Nigeria');

      expect(profile.country, 'Nigeria');
    });

    test('8 — updates avatar URL and returns updated UserProfile', () async {
      const url = 'https://example.com/avatars/player.png';
      buildServices(MockClient((_) async =>
          _profileResponse(overrides: {'avatar': url})));

      final profile = await profileService.updateProfile(avatar: url);

      expect(profile.avatar, url);
    });

    test('9 — clears avatar by passing null', () async {
      buildServices(MockClient((_) async =>
          _profileResponse(overrides: {'avatar': null})));

      final profile = await profileService.updateProfile(avatar: null);

      expect(profile.avatar, isNull);
    });

    test('10 — clears country by passing null', () async {
      buildServices(MockClient((_) async =>
          _profileResponse(overrides: {'country': null})));

      final profile = await profileService.updateProfile(country: null);

      expect(profile.country, isNull);
    });

    test('11 — throws ApiException on 400 validation error', () async {
      buildServices(MockClient((_) async => _jsonResponse(
            {
              'success': false,
              'message': 'Validation failed.',
              'errors': [
                {'field': 'full_name', 'message': 'Full name must be at least 2 characters.'}
              ],
            },
            status: 400,
          )));

      await expectLater(
        () => profileService.updateProfile(fullName: 'X'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('12 — throws SessionExpiredException on 401 when refresh fails', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token': 'expired-token',
        'ludo_refresh_token': 'expired-refresh-token',
      });

      buildServices(MockClient((req) async {
        // Both profile and refresh endpoints reject → session truly expired
        return _jsonResponse(
          {'success': false, 'message': 'Token expired.'},
          status: 401,
        );
      }));

      await expectLater(
        () => profileService.updateProfile(fullName: 'New Name'),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('13 — throws ArgumentError when no fields are provided', () async {
      buildServices(MockClient((_) async => throw UnimplementedError()));

      await expectLater(
        () => profileService.updateProfile(),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ─── UserProfile.fromJson ──────────────────────────────────────────────────

  group('UserProfile.fromJson (profile endpoint shape)', () {
    test('14 — parses all fields correctly, including updatedAt', () async {
      buildServices(MockClient((_) async => _profileResponse()));

      final profile = await profileService.getProfile();

      expect(profile.id, 'user-uuid-1');
      expect(profile.playerId, 'LUD-ABC123');
      expect(profile.fullName, 'Test Player');
      expect(profile.email, 'test@example.com');
      expect(profile.mobile, isNull);
      expect(profile.country, 'NG');
      expect(profile.avatar, isNull);
      expect(profile.status, 'active');
      expect(profile.createdAt, '2026-07-15T00:00:00.000Z');
      expect(profile.updatedAt, '2026-07-17T00:00:00.000Z');
    });

    test('15 — nullable fields are null without cast error', () async {
      buildServices(MockClient((_) async => _profileResponse(
            overrides: {
              'email': null,
              'mobile': null,
              'country': null,
              'avatar': null,
              'updated_at': null,
            },
          )));

      final profile = await profileService.getProfile();

      expect(profile.email, isNull);
      expect(profile.mobile, isNull);
      expect(profile.country, isNull);
      expect(profile.avatar, isNull);
      expect(profile.updatedAt, isNull);
    });
  });
}
