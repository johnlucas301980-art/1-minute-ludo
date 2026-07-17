import '../../../core/network/api_client.dart';
import '../../auth/models/user_profile.dart';

// ---------------------------------------------------------------------------
// Private sentinel
// ---------------------------------------------------------------------------

/// Distinguishes "field not provided" from "explicit null" for nullable
/// parameters that may be used to clear a backend field.
///
/// Dart cannot tell apart:
///   updateProfile(avatar: null)   // caller wants to clear the field → send null
///   updateProfile()               // caller did not mention avatar    → omit key
/// with a plain [String?] parameter.  Using [Object?] with this const default
/// solves the ambiguity without exposing boolean flags to call sites.
class _Absent {
  const _Absent();
}

const Object _absent = _Absent();

// ---------------------------------------------------------------------------
// ProfileService
// ---------------------------------------------------------------------------

/// Provides profile operations for the 1 Minute Ludo app.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage = TokenStorage();
/// final client  = ApiClient(tokenStorage: storage);
/// final profile = ProfileService(apiClient: client);
/// ```
class ProfileService {
  ProfileService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Get Profile ────────────────────────────────────────────────────────────

  /// Fetches the authenticated player's profile from the backend.
  ///
  /// Returns a [UserProfile] populated from GET /api/profile, including
  /// [UserProfile.updatedAt].
  ///
  /// Throws [ApiException] on non-2xx responses.
  /// Throws [SessionExpiredException] when the token refresh also fails.
  Future<UserProfile> getProfile() async {
    final json = await _api.authenticatedRequest('GET', '/profile');
    final data = json['data'] as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  // ─── Update Profile ─────────────────────────────────────────────────────────

  /// Updates one or more mutable profile fields via PUT /api/profile.
  ///
  /// **Partial update** — only keys that were explicitly supplied are sent.
  /// Omitting a parameter leaves the corresponding field unchanged on the server.
  ///
  /// **Clearing nullable fields** — pass `null` explicitly to [country] or
  /// [avatar] to remove the value from the player's profile:
  /// ```dart
  /// // Clear the avatar:
  /// await profileService.updateProfile(avatar: null);
  ///
  /// // Update the display name only (country and avatar are untouched):
  /// await profileService.updateProfile(fullName: 'New Name');
  /// ```
  ///
  /// Throws [ArgumentError] if no fields are provided.
  /// Throws [ApiException] on non-2xx responses (e.g. 400 validation error).
  /// Throws [SessionExpiredException] when the token refresh also fails.
  Future<UserProfile> updateProfile({
    String? fullName,
    Object? country = _absent,
    Object? avatar = _absent,
  }) async {
    final hasFullName = fullName != null;
    final hasCountry = country != _absent;
    final hasAvatar = avatar != _absent;

    if (!hasFullName && !hasCountry && !hasAvatar) {
      throw ArgumentError(
        'At least one field (fullName, country, avatar) must be provided.',
      );
    }

    final body = <String, dynamic>{};
    if (hasFullName) body['full_name'] = fullName;
    if (hasCountry) body['country'] = country;
    if (hasAvatar) body['avatar'] = avatar;

    final json = await _api.authenticatedRequest('PUT', '/profile', body: body);
    final data = json['data'] as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }
}
