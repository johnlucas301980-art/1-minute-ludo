/// Represents a player's profile as returned by the backend.
///
/// Constructed from the `data.profile` object of a successful login response,
/// or the `data` object of a successful register response.
/// `password_hash` is never present in backend responses and is never stored.
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
    );
  }

  @override
  String toString() =>
      'UserProfile(playerId: $playerId, fullName: $fullName, status: $status)';
}
