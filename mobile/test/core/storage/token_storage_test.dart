import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';

void main() {
  group('TokenStorage', () {
    late TokenStorage storage;

    setUp(() {
      // flutter_secure_storage provides an in-memory test back-end when
      // setMockInitialValues is called before each test.
      FlutterSecureStorage.setMockInitialValues({});
      storage = const TokenStorage();
    });

    test('returns null when no tokens have been saved', () async {
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('saveTokens stores both access and refresh tokens', () async {
      await storage.saveTokens(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
      );
      expect(await storage.getAccessToken(), 'access-abc');
      expect(await storage.getRefreshToken(), 'refresh-xyz');
    });

    test('saveAccessToken overwrites only the access token', () async {
      await storage.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'refresh-xyz',
      );
      await storage.saveAccessToken('new-access');
      expect(await storage.getAccessToken(), 'new-access');
      expect(await storage.getRefreshToken(), 'refresh-xyz');
    });

    test('clearAll removes both tokens', () async {
      await storage.saveTokens(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
      );
      await storage.clearAll();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
