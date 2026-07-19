/// Model for the `game_over` Socket.IO event emitted by the server when a
/// match finishes — either by forfeit (Phase 5.6) or by gameplay completion
/// (Phase 6).
///
/// Phase 5.6 only sends reason `'forfeit'`.
/// Phase 6 will add `'completed'` when a player wins by moving all pawns home.
class GameOver {
  const GameOver({
    required this.matchId,
    required this.winnerId,
    required this.reason,
  });

  /// UUID of the finished match.
  final String matchId;

  /// UUID of the winning user.
  final String winnerId;

  /// Why the match ended: `'forfeit'` or `'completed'` (Phase 6).
  final String reason;

  factory GameOver.fromJson(Map<String, dynamic> json) {
    final matchId  = json['matchId']  as String?;
    final winnerId = json['winnerId'] as String?;
    final reason   = json['reason']   as String?;

    if (matchId == null || winnerId == null || reason == null) {
      throw const FormatException('game_over payload missing required fields.');
    }

    return GameOver(matchId: matchId, winnerId: winnerId, reason: reason);
  }

  @override
  String toString() =>
      'GameOver(matchId: $matchId, winnerId: $winnerId, reason: $reason)';

  @override
  bool operator ==(Object other) =>
      other is GameOver &&
      other.matchId  == matchId  &&
      other.winnerId == winnerId &&
      other.reason   == reason;

  @override
  int get hashCode => Object.hash(matchId, winnerId, reason);
}
