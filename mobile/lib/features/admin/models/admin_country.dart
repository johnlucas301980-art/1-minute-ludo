/// Represents a country record as returned by the admin API.
class AdminCountry {
  final String iso2;
  final String name;
  final bool isAllowed;
  final bool allowRegistration;
  final bool allowLogin;
  final bool allowGameplay;
  final bool allowRecharge;
  final bool allowWithdraw;
  final bool allowTournament;

  const AdminCountry({
    required this.iso2,
    required this.name,
    required this.isAllowed,
    required this.allowRegistration,
    required this.allowLogin,
    required this.allowGameplay,
    required this.allowRecharge,
    required this.allowWithdraw,
    required this.allowTournament,
  });

  factory AdminCountry.fromJson(Map<String, dynamic> json) => AdminCountry(
        iso2: json['iso2'] as String,
        name: json['name'] as String,
        isAllowed: json['is_allowed'] as bool,
        allowRegistration: json['allow_registration'] as bool,
        allowLogin: json['allow_login'] as bool,
        allowGameplay: json['allow_gameplay'] as bool,
        allowRecharge: json['allow_recharge'] as bool,
        allowWithdraw: json['allow_withdraw'] as bool,
        allowTournament: json['allow_tournament'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'iso2': iso2,
        'name': name,
        'is_allowed': isAllowed,
        'allow_registration': allowRegistration,
        'allow_login': allowLogin,
        'allow_gameplay': allowGameplay,
        'allow_recharge': allowRecharge,
        'allow_withdraw': allowWithdraw,
        'allow_tournament': allowTournament,
      };

  AdminCountry copyWith({
    String? iso2,
    String? name,
    bool? isAllowed,
    bool? allowRegistration,
    bool? allowLogin,
    bool? allowGameplay,
    bool? allowRecharge,
    bool? allowWithdraw,
    bool? allowTournament,
  }) =>
      AdminCountry(
        iso2: iso2 ?? this.iso2,
        name: name ?? this.name,
        isAllowed: isAllowed ?? this.isAllowed,
        allowRegistration: allowRegistration ?? this.allowRegistration,
        allowLogin: allowLogin ?? this.allowLogin,
        allowGameplay: allowGameplay ?? this.allowGameplay,
        allowRecharge: allowRecharge ?? this.allowRecharge,
        allowWithdraw: allowWithdraw ?? this.allowWithdraw,
        allowTournament: allowTournament ?? this.allowTournament,
      );

  @override
  String toString() => 'AdminCountry('
      'iso2: $iso2, '
      'name: $name, '
      'isAllowed: $isAllowed, '
      'allowRegistration: $allowRegistration, '
      'allowLogin: $allowLogin, '
      'allowGameplay: $allowGameplay, '
      'allowRecharge: $allowRecharge, '
      'allowWithdraw: $allowWithdraw, '
      'allowTournament: $allowTournament)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminCountry &&
          runtimeType == other.runtimeType &&
          iso2 == other.iso2 &&
          name == other.name &&
          isAllowed == other.isAllowed &&
          allowRegistration == other.allowRegistration &&
          allowLogin == other.allowLogin &&
          allowGameplay == other.allowGameplay &&
          allowRecharge == other.allowRecharge &&
          allowWithdraw == other.allowWithdraw &&
          allowTournament == other.allowTournament;

  @override
  int get hashCode => Object.hash(
        iso2,
        name,
        isAllowed,
        allowRegistration,
        allowLogin,
        allowGameplay,
        allowRecharge,
        allowWithdraw,
        allowTournament,
      );
}
