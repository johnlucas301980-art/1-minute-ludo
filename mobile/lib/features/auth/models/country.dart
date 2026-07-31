/// Represents a country returned by GET /api/geo/detect.
class Country {
  const Country({
    required this.iso2,
    required this.name,
    required this.dialCode,
    required this.phoneExample,
    required this.isAllowed,
    required this.allowRegistration,
    required this.allowLogin,
  });

  /// ISO 3166-1 alpha-2 code (e.g. "IN", "US", "DE").
  final String iso2;

  /// Human-readable country name (e.g. "India").
  final String name;

  /// International dial code including leading '+' (e.g. "+91").
  final String dialCode;

  /// Full E.164 example number for this country (e.g. "+919876543210").
  final String phoneExample;

  final bool isAllowed;
  final bool allowRegistration;
  final bool allowLogin;

  /// Unicode flag emoji for this country (built from regional indicator letters).
  String get flagEmoji {
    return iso2.toUpperCase().split('').map((c) {
      return String.fromCharCode(0x1F1E0 + c.codeUnitAt(0) - 'A'.codeUnitAt(0));
    }).join();
  }

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      iso2:              json['iso2']               as String? ?? '',
      name:              json['name']               as String? ?? '',
      dialCode:          json['dial_code']           as String? ?? '',
      phoneExample:      json['phone_example']       as String? ?? '',
      isAllowed:         json['is_allowed']          as bool?   ?? true,
      allowRegistration: json['allow_registration']  as bool?   ?? true,
      allowLogin:        json['allow_login']         as bool?   ?? true,
    );
  }

  @override
  bool operator ==(Object other) => other is Country && other.iso2 == iso2;

  @override
  int get hashCode => iso2.hashCode;

  @override
  String toString() => 'Country($iso2, $name)';
}
