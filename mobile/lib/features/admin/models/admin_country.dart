/// Represents a country record as returned by the admin API.
class AdminCountry {
  final String iso2;
  final String name;
  final bool isActive;

  const AdminCountry({
    required this.iso2,
    required this.name,
    required this.isActive,
  });

  factory AdminCountry.fromJson(Map<String, dynamic> json) => AdminCountry(
        iso2: json['iso2'] as String,
        name: json['name'] as String,
        isActive: json['isActive'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'iso2': iso2,
        'name': name,
        'isActive': isActive,
      };

  AdminCountry copyWith({
    String? iso2,
    String? name,
    bool? isActive,
  }) =>
      AdminCountry(
        iso2: iso2 ?? this.iso2,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
      );

  @override
  String toString() =>
      'AdminCountry(iso2: $iso2, name: $name, isActive: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminCountry &&
          runtimeType == other.runtimeType &&
          iso2 == other.iso2 &&
          name == other.name &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(iso2, name, isActive);
}
