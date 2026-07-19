/// Payload of the `pawn_moved` Socket.IO event (Phase 6.2).
///
/// Emitted by the server to all players in the room after a pawn move is
/// applied.  When [capturedColor] is non-null a capture occurred and the
/// captured pawn has been sent back to the yard (position 0).
///
/// After receiving this event the client should await either:
///   - `game_over`    — the moving player won (all 4 pawns at position 57).
///   - `turn_changed` — the turn has been resolved (same or next player).
class PawnMoved {
  const PawnMoved({
    required this.matchId,
    required this.color,
    required this.pawnIndex,
    required this.toPosition,
    this.capturedColor,
    this.capturedPawnIndex,
  });

  /// UUID of the match.
  final String matchId;

  /// Board colour of the player who moved.
  /// One of: red, blue, green, yellow.
  final String color;

  /// Index of the pawn that was moved (0–3).
  final int pawnIndex;

  /// Colour-relative destination position after the move.
  final int toPosition;

  /// Colour of the captured opponent pawn, or `null` if no capture occurred.
  final String? capturedColor;

  /// Index of the captured pawn (0–3), or `null` if no capture occurred.
  final int? capturedPawnIndex;

  factory PawnMoved.fromJson(Map<String, dynamic> json) {
    final matchId   = json['matchId']   as String?;
    final color     = json['color']     as String?;
    final pawnIndex = json['pawnIndex'];
    final toPos     = json['toPosition'];

    if (matchId == null || color == null ||
        pawnIndex is! int || toPos is! int) {
      throw const FormatException(
          'pawn_moved payload missing required fields '
          '(matchId, color, pawnIndex, toPosition).');
    }

    return PawnMoved(
      matchId:           matchId,
      color:             color,
      pawnIndex:         pawnIndex,
      toPosition:        toPos,
      capturedColor:     json['capturedColor']     as String?,
      capturedPawnIndex: json['capturedPawnIndex'] as int?,
    );
  }

  @override
  String toString() => 'PawnMoved(matchId: $matchId, color: $color, '
      'pawnIndex: $pawnIndex, toPosition: $toPosition, '
      'capturedColor: $capturedColor, capturedPawnIndex: $capturedPawnIndex)';

  @override
  bool operator ==(Object other) =>
      other is PawnMoved                              &&
      other.matchId           == matchId             &&
      other.color             == color               &&
      other.pawnIndex         == pawnIndex           &&
      other.toPosition        == toPosition          &&
      other.capturedColor     == capturedColor       &&
      other.capturedPawnIndex == capturedPawnIndex;

  @override
  int get hashCode => Object.hash(
    matchId, color, pawnIndex, toPosition, capturedColor, capturedPawnIndex,
  );
}
