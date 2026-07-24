/// A user record as returned by the admin API.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.playerId,
    required this.fullName,
    required this.role,
    required this.status,
    required this.isVerified,
    required this.createdAt,
    this.email,
    this.mobile,
    this.country,
    this.lastLoginAt,
  });

  final String   id;
  final String   playerId;
  final String   fullName;
  final String   role;
  final String   status;
  final bool     isVerified;
  final DateTime createdAt;
  final String?  email;
  final String?  mobile;
  final String?  country;
  final DateTime? lastLoginAt;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final id        = json['id'];
    final playerId  = json['player_id'];
    final fullName  = json['full_name'];
    final role      = json['role'];
    final status    = json['status'];
    final isVerified = json['is_verified'];
    final createdAt = json['created_at'];

    if (id is! String ||
        playerId is! String ||
        fullName is! String ||
        role is! String ||
        status is! String ||
        isVerified is! bool ||
        createdAt is! String) {
      throw const FormatException('Invalid admin user payload.');
    }

    final rawLastLogin = json['last_login_at'];

    return AdminUser(
      id:          id,
      playerId:    playerId,
      fullName:    fullName,
      role:        role,
      status:      status,
      isVerified:  isVerified,
      createdAt:   DateTime.parse(createdAt).toLocal(),
      email:       json['email'] as String?,
      mobile:      json['mobile'] as String?,
      country:     json['country'] as String?,
      lastLoginAt: rawLastLogin is String
          ? DateTime.parse(rawLastLogin).toLocal()
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AdminUser(id: $id, playerId: $playerId, role: $role, status: $status)';
}
