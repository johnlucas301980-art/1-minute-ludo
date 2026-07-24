/// A persisted in-app notification returned by REST or Socket.IO.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.relatedType,
    required this.relatedId,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String? relatedType;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      relatedType: relatedType,
      relatedId: relatedId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final title = json['title'];
    final message = json['message'];
    final createdAt = json['created_at'];

    if (id is! String ||
        type is! String ||
        title is! String ||
        message is! String ||
        createdAt is! String) {
      throw const FormatException('Invalid notification payload.');
    }

    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      relatedType: json['related_type'] as String?,
      relatedId: json['related_id'] as String?,
      isRead: json['is_read'] == true,
      createdAt: DateTime.parse(createdAt).toLocal(),
      readAt: (json['read_at'] as String?) == null
          ? null
          : DateTime.parse(json['read_at'] as String).toLocal(),
    );
  }
}