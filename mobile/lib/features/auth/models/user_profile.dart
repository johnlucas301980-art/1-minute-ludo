/// Represents a player's profile as returned by the backend.
///
/// Constructed from the `data.profile` object of a successful login response,
/// the `data` object of a successful register response, or the `data.profile`
/// object of a GET /profile or PUT /profile response.
///
/// `password_hash` is never present in backend responses and is never stored.
///
/// [updatedAt] is present on profile-endpoint responses (Phase 3.1 and later)
/// but absent from auth responses; it is therefore optional.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.playerId,
    required this.fullName,
    this.email,
    this.mobile,
    this.country,
    this.avatar,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String playerId;
  final String fullName;
  final String? email;
  final String? mobile;
  final String? country;
  final String? avatar;
  final String status;
  final String createdAt;

  /// ISO-8601 timestamp of the last profile update.
  /// Present on GET /profile and PUT /profile responses; null for auth responses.
  final String? updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      mobile: json['mobile'] as String?,
      country: json['country'] as String?,
      avatar: json['avatar'] as String?,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String?,
    );
  }

  @override
  String toString() =>
      'UserProfile(playerId: $playerId, fullName: $fullName, status: $status)';
}
