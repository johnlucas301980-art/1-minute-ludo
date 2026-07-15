import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_tokens.dart';
import '../models/user_profile.dart';

/// Provides authentication operations for the 1 Minute Ludo app.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage = TokenStorage();
/// final client  = ApiClient(tokenStorage: storage);
/// final auth    = AuthService(apiClient: client, tokenStorage: storage);
/// ```
class AuthService {
  AuthService({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _api = apiClient,
        _storage = tokenStorage;

  final ApiClient _api;
  final TokenStorage _storage;

  // ─── Register ───────────────────────────────────────────────────────────────

  /// Creates a new player account.
  ///
  /// Returns the created [UserProfile].
  /// Throws [ApiException] on validation errors (400) or duplicate (409).
  Future<UserProfile> register({
    required String fullName,
    required String password,
    String? email,
    String? mobile,
    String? country,
  }) async {
    final body = <String, dynamic>{
      'full_name': fullName,
      'password': password,
      if (email != null) 'email': email,
      if (mobile != null) 'mobile': mobile,
      if (country != null) 'country': country,
    };

    final json = await _api.publicRequest('POST', '/auth/register', body: body);
    return UserProfile.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ─── Login ──────────────────────────────────────────────────────────────────

  /// Authenticates with email or mobile + password.
  ///
  /// On success, stores both tokens securely and returns the [UserProfile].
  /// Throws [ApiException] (401) on invalid credentials.
  /// Throws [AccountForbiddenException] (403) on suspended / banned account.
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    final json = await _api.publicRequest(
      'POST',
      '/auth/login',
      body: {'identifier': identifier, 'password': password},
    );

    final data = json['data'] as Map<String, dynamic>;
    final tokens = AuthTokens.fromJson(data);

    // Persist tokens — never logged.
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  // ─── Logout ─────────────────────────────────────────────────────────────────

  /// Revokes the refresh token on the server and clears local storage.
  ///
  /// [allDevices] — when `true`, revokes every session for this account.
  ///               When `false` (default), revokes only the current device's token.
  ///
  /// Token storage is always cleared locally, even if the server call fails,
  /// so the user is always considered logged out after this returns.
  Future<void> logout({bool allDevices = false}) async {
    final refreshToken = await _storage.getRefreshToken();

    try {
      final body = <String, dynamic>{
        'all_devices': allDevices,
        if (!allDevices && refreshToken != null) 'refresh_token': refreshToken,
      };
      await _api.authenticatedRequest('POST', '/auth/logout', body: body);
    } catch (_) {
      // Server-side revocation failed — local logout still proceeds.
    } finally {
      // Always clear local tokens regardless of server response.
      await _storage.clearAll();
    }
  }

  // ─── Session helpers ─────────────────────────────────────────────────────────

  /// Returns `true` if an access token is present in storage.
  ///
  /// Note: the token may be expired — use this only as a lightweight check.
  /// The [ApiClient] will handle expiry transparently via silent refresh.
  Future<bool> isLoggedIn() async {
    final token = await _storage.getAccessToken();
    return token != null;
  }
}
