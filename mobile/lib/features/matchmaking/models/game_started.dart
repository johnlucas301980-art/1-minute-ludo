/// Payload of the `game_start` Socket.IO event.
///
/// Emitted by the server ~2.5 seconds after `room_ready`, once the match
/// status has been set to `in_progress` in the database and the first turn
/// has been determined.
class GameStarted {
  const GameStarted({
    required this.matchId,
    required this.firstTurn,
  });

  /// UUID of the match that has started.
  final String matchId;

  /// The board colour of the player who goes first.
  /// One of: red, blue, green, yellow.
  final String firstTurn;

  factory GameStarted.fromJson(Map<String, dynamic> json) {
    return GameStarted(
      matchId:   json['matchId']   as String,
      firstTurn: json['firstTurn'] as String,
    );
  }

  @override
  String toString() =>
      'GameStarted(matchId: $matchId, firstTurn: $firstTurn)';
}
