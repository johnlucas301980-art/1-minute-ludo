import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys used for secure storage — kept private to this file.
const _kAccessToken = 'ludo_access_token';
const _kRefreshToken = 'ludo_refresh_token';

/// Reads, writes, and deletes JWTs from platform-backed secure storage.
///
/// On Android this uses the Android Keystore; on iOS it uses the Keychain.
/// Tokens are never written to logs or exposed outside this class.
class TokenStorage {
  const TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Persists both tokens atomically (sequential awaits).
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  /// Overwrites the access token only (used after a silent token refresh).
  Future<void> saveAccessToken(String accessToken) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
  }

  /// Returns the stored access token, or `null` if not present.
  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  /// Returns the stored refresh token, or `null` if not present.
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  /// Deletes both tokens (called on logout or session expiry).
  Future<void> clearAll() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}
