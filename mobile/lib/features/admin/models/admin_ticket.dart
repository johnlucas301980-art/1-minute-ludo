/// A support ticket as returned by the admin API (includes user identity).
class AdminTicket {
  const AdminTicket({
    required this.id,
    required this.userId,
    required this.playerId,
    required this.fullName,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String   id;
  final String   userId;
  final String   playerId;
  final String   fullName;
  final String   subject;
  final String   message;
  final String   status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminTicket.fromJson(Map<String, dynamic> json) {
    final id        = json['id'];
    final userId    = json['user_id'];
    final playerId  = json['player_id'];
    final fullName  = json['full_name'];
    final subject   = json['subject'];
    final message   = json['message'];
    final status    = json['status'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];

    if (id is! String ||
        userId is! String ||
        playerId is! String ||
        fullName is! String ||
        subject is! String ||
        message is! String ||
        status is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid admin ticket payload.');
    }

    return AdminTicket(
      id:        id,
      userId:    userId,
      playerId:  playerId,
      fullName:  fullName,
      subject:   subject,
      message:   message,
      status:    status,
      createdAt: DateTime.parse(createdAt).toLocal(),
      updatedAt: DateTime.parse(updatedAt).toLocal(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminTicket && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AdminTicket(id: $id, subject: $subject, status: $status)';
}
