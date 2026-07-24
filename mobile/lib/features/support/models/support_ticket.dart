/// A support ticket submitted by the authenticated player.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final userId = json['user_id'];
    final subject = json['subject'];
    final message = json['message'];
    final status = json['status'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];

    if (id is! String ||
        userId is! String ||
        subject is! String ||
        message is! String ||
        status is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid support ticket payload.');
    }

    return SupportTicket(
      id: id,
      userId: userId,
      subject: subject,
      message: message,
      status: status,
      createdAt: DateTime.parse(createdAt).toLocal(),
      updatedAt: DateTime.parse(updatedAt).toLocal(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportTicket &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          subject == other.subject &&
          message == other.message &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, userId, subject, message, status, createdAt, updatedAt);

  @override
  String toString() =>
      'SupportTicket(id: $id, subject: $subject, status: $status)';
}
