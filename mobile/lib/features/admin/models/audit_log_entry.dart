/// A single entry in the admin audit log.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.adminId,
    required this.adminPlayerId,
    required this.adminFullName,
    required this.action,
    required this.createdAt,
    this.targetUserId,
    this.targetPlayerId,
    this.targetFullName,
    this.oldValue,
    this.newValue,
    this.details,
  });

  final String  id;
  final String  adminId;
  final String  adminPlayerId;
  final String  adminFullName;
  final String  action;
  final DateTime createdAt;

  final String?              targetUserId;
  final String?              targetPlayerId;
  final String?              targetFullName;
  final String?              oldValue;
  final String?              newValue;
  final Map<String, dynamic>? details;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final id            = json['id'];
    final adminId       = json['admin_id'];
    final adminPlayerId = json['admin_player_id'];
    final adminFullName = json['admin_full_name'];
    final action        = json['action'];
    final createdAt     = json['created_at'];

    if (id is! String ||
        adminId is! String ||
        adminPlayerId is! String ||
        adminFullName is! String ||
        action is! String ||
        createdAt is! String) {
      throw const FormatException('Invalid audit log entry payload.');
    }

    return AuditLogEntry(
      id:             id,
      adminId:        adminId,
      adminPlayerId:  adminPlayerId,
      adminFullName:  adminFullName,
      action:         action,
      createdAt:      DateTime.parse(createdAt).toLocal(),
      targetUserId:   json['target_user_id'] as String?,
      targetPlayerId: json['target_player_id'] as String?,
      targetFullName: json['target_full_name'] as String?,
      oldValue:       json['old_value'] as String?,
      newValue:       json['new_value'] as String?,
      details:        json['details'] as Map<String, dynamic>?,
    );
  }

  /// Human-readable summary of what changed.
  String get summary {
    switch (action) {
      case 'ban':
        return 'Banned ${targetFullName ?? targetPlayerId ?? targetUserId}';
      case 'unban':
        return 'Unbanned ${targetFullName ?? targetPlayerId ?? targetUserId}';
      case 'promote':
        return 'Promoted ${targetFullName ?? targetPlayerId ?? targetUserId} to admin';
      case 'demote':
        return 'Demoted ${targetFullName ?? targetPlayerId ?? targetUserId} to player';
      case 'status_change':
        return 'Changed status of ${targetFullName ?? targetPlayerId ?? targetUserId}: $oldValue → $newValue';
      case 'role_change':
        return 'Changed role of ${targetFullName ?? targetPlayerId ?? targetUserId}: $oldValue → $newValue';
      case 'ticket_status_change':
        return 'Updated ticket status → $newValue for ${targetFullName ?? targetPlayerId ?? targetUserId}';
      default:
        return action;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditLogEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AuditLogEntry(id: $id, action: $action)';
}
