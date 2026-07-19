import 'valid_move.dart';

/// Payload of the `dice_rolled` Socket.IO event (Phase 6.1).
///
/// Emitted by the server to all players in the room after a player rolls the
/// dice.  Contains the dice value and the list of legal moves available to the
/// rolling player.
///
/// If [validMoves] is empty the server passes the turn immediately and emits
/// `turn_changed` — the rolling player has no legal moves this turn.
class DiceRolled {
  const DiceRolled({
    required this.matchId,
    required this.color,
    required this.value,
    required this.validMoves,
  });

  /// UUID of the match.
  final String matchId;

  /// Board colour of the player who rolled.
  /// One of: red, blue, green, yellow.
  final String color;

  /// Dice value (1–6).
  final int value;

  /// Legal moves available to the rolling player.
  /// Empty when no pawn can legally move with this dice value.
  final List<ValidMove> validMoves;

  factory DiceRolled.fromJson(Map<String, dynamic> json) {
    final matchId = json['matchId'] as String?;
    final color   = json['color']   as String?;
    final value   = json['value'];

    if (matchId == null || color == null || value is! int) {
      throw const FormatException(
          'dice_rolled payload missing required fields (matchId, color, value).');
    }

    final rawMoves = json['validMoves'];
    final validMoves = <ValidMove>[];
    if (rawMoves is List) {
      for (final item in rawMoves) {
        if (item is Map) {
          validMoves.add(
            ValidMove.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }

    return DiceRolled(
      matchId:    matchId,
      color:      color,
      value:      value,
      validMoves: validMoves,
    );
  }

  @override
  String toString() => 'DiceRolled(matchId: $matchId, color: $color, '
      'value: $value, validMoves: $validMoves)';

  @override
  bool operator ==(Object other) =>
      other is DiceRolled            &&
      other.matchId    == matchId    &&
      other.color      == color      &&
      other.value      == value      &&
      _listEquals(other.validMoves, validMoves);

  @override
  int get hashCode => Object.hash(matchId, color, value, Object.hashAll(validMoves));

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
