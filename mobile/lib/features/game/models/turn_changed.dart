/// Payload of the `turn_changed` Socket.IO event (Phase 6.1 / 6.2).
///
/// Emitted by the server to all players in the room to signal that the active
/// turn has been resolved and a new turn is starting.
///
/// Emitted when:
///   - The rolling player had no valid moves — turn passes to opponent.
///   - A pawn was moved after a non-6 dice roll — turn passes to opponent.
///   - A pawn was moved after rolling 6 — same player gets an extra turn
///     ([nextTurn] equals the mover's colour).
class TurnChanged {
  const TurnChanged({
    required this.matchId,
    required this.nextTurn,
  });

  /// UUID of the match.
  final String matchId;

  /// Board colour of the player who must now roll.
  /// One of: red, blue, green, yellow.
  final String nextTurn;

  factory TurnChanged.fromJson(Map<String, dynamic> json) {
    final matchId  = json['matchId']  as String?;
    final nextTurn = json['nextTurn'] as String?;

    if (matchId == null || nextTurn == null) {
      throw const FormatException(
          'turn_changed payload missing required fields (matchId, nextTurn).');
    }

    return TurnChanged(matchId: matchId, nextTurn: nextTurn);
  }

  @override
  String toString() =>
      'TurnChanged(matchId: $matchId, nextTurn: $nextTurn)';

  @override
  bool operator ==(Object other) =>
      other is TurnChanged        &&
      other.matchId  == matchId  &&
      other.nextTurn == nextTurn;

  @override
  int get hashCode => Object.hash(matchId, nextTurn);
}
