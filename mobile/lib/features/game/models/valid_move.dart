/// A single legal pawn move computed server-side after a dice roll.
///
/// Returned inside [DiceRolled.validMoves].  The client must select one of
/// the listed moves and emit `move_pawn { matchId, pawnIndex }` to the server.
///
/// Position encoding (colour-relative):
///   0       = yard (home base, not on the board)
///   1–51    = shared track
///   52–56   = home column (colour-specific, cannot be captured)
///   57      = finished (in the centre)
class ValidMove {
  const ValidMove({
    required this.pawnIndex,
    required this.fromPos,
    required this.toPos,
  });

  /// Index of the pawn that can move (0–3).
  final int pawnIndex;

  /// Current colour-relative position of the pawn before the move.
  final int fromPos;

  /// Colour-relative position the pawn would reach after the move.
  final int toPos;

  factory ValidMove.fromJson(Map<String, dynamic> json) {
    final pawnIndex = json['pawnIndex'];
    final fromPos   = json['fromPos'];
    final toPos     = json['toPos'];

    if (pawnIndex is! int || fromPos is! int || toPos is! int) {
      throw const FormatException(
          'ValidMove: pawnIndex, fromPos and toPos must all be integers.');
    }

    return ValidMove(pawnIndex: pawnIndex, fromPos: fromPos, toPos: toPos);
  }

  @override
  String toString() =>
      'ValidMove(pawnIndex: $pawnIndex, fromPos: $fromPos, toPos: $toPos)';

  @override
  bool operator ==(Object other) =>
      other is ValidMove &&
      other.pawnIndex == pawnIndex &&
      other.fromPos   == fromPos   &&
      other.toPos     == toPos;

  @override
  int get hashCode => Object.hash(pawnIndex, fromPos, toPos);
}
