/// Represents the opponent in a matched game, as returned inside
/// the `match_found` Socket.IO event.
class Opponent {
  const Opponent({
    required this.playerId,
    required this.fullName,
    this.avatar,
  });

  /// The opponent's public player ID (e.g. "LUD-A1B2C3").
  final String playerId;

  /// The opponent's display name.
  final String fullName;

  /// URL of the opponent's avatar image, or null when not set.
  final String? avatar;

  factory Opponent.fromJson(Map<String, dynamic> json) {
    return Opponent(
      playerId: json['playerId'] as String,
      fullName: json['fullName'] as String,
      avatar:   json['avatar']   as String?,
    );
  }

  @override
  String toString() =>
      'Opponent(playerId: $playerId, fullName: $fullName, avatar: $avatar)';
}
