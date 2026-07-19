import 'opponent.dart';

/// Represents the payload of the `match_found` Socket.IO event.
///
/// Emitted by the server to both matched players when a new match is created.
class MatchFound {
  const MatchFound({
    required this.matchId,
    required this.roomCode,
    required this.color,
    required this.opponent,
  });

  /// UUID of the newly created match row.
  final String matchId;

  /// 6-character alphanumeric room code (e.g. "AB3Z9K").
  final String roomCode;

  /// Board color assigned to the receiving player.
  /// One of: red, blue, green, yellow.
  final String color;

  /// The player's opponent in this match.
  final Opponent opponent;

  factory MatchFound.fromJson(Map<String, dynamic> json) {
    return MatchFound(
      matchId:  json['matchId']  as String,
      roomCode: json['roomCode'] as String,
      color:    json['color']    as String,
      opponent: Opponent.fromJson(json['opponent'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() =>
      'MatchFound(matchId: $matchId, roomCode: $roomCode, '
      'color: $color, opponent: $opponent)';
}
