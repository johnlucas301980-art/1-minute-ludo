/// An admin-managed application setting — Phase 10.4.

class AdminSetting {
  const AdminSetting({
    required this.id,
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  final String id;
  final String key;
  final String value;
  final DateTime updatedAt;

  factory AdminSetting.fromJson(Map<String, dynamic> json) => AdminSetting(
        id: json['id'] as String,
        key: json['key'] as String,
        value: json['value'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AdminSetting && key == other.key;

  @override
  int get hashCode => key.hashCode;
}