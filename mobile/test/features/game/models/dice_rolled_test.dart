import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/dice_rolled.dart';
import 'package:one_minute_ludo/features/game/models/valid_move.dart';

void main() {
  const kMatchId = 'match-uuid-1';

  // ── fromJson ───────────────────────────────────────────────────────────────

  group('DiceRolled.fromJson', () {
    test('1 — parses a full payload with valid moves', () {
      final event = DiceRolled.fromJson({
        'matchId': kMatchId,
        'color':   'red',
        'value':   6,
        'validMoves': [
          {'pawnIndex': 0, 'fromPos': 0, 'toPos': 1},
          {'pawnIndex': 2, 'fromPos': 15, 'toPos': 21},
        ],
      });
      expect(event.matchId,    kMatchId);
      expect(event.color,      'red');
      expect(event.value,      6);
      expect(event.validMoves, hasLength(2));
      expect(event.validMoves[0].pawnIndex, 0);
      expect(event.validMoves[1].toPos,     21);
    });

    test('2 — parses payload with empty validMoves list', () {
      final event = DiceRolled.fromJson({
        'matchId':    kMatchId,
        'color':      'blue',
        'value':      3,
        'validMoves': <dynamic>[],
      });
      expect(event.validMoves, isEmpty);
    });

    test('3 — treats missing validMoves key as empty list', () {
      final event = DiceRolled.fromJson({
        'matchId': kMatchId,
        'color':   'green',
        'value':   2,
      });
      expect(event.validMoves, isEmpty);
    });

    test('4 — throws FormatException when matchId is missing', () {
      expect(
        () => DiceRolled.fromJson({'color': 'red', 'value': 3, 'validMoves': []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('5 — throws FormatException when value is a string', () {
      expect(
        () => DiceRolled.fromJson(
            {'matchId': kMatchId, 'color': 'red', 'value': '4', 'validMoves': []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('6 — throws FormatException when color is missing', () {
      expect(
        () => DiceRolled.fromJson(
            {'matchId': kMatchId, 'value': 5, 'validMoves': []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('7 — skips malformed entries inside validMoves list', () {
      // One valid entry and one malformed — only the valid one survives.
      final event = DiceRolled.fromJson({
        'matchId': kMatchId,
        'color':   'yellow',
        'value':   5,
        'validMoves': [
          {'pawnIndex': 1, 'fromPos': 10, 'toPos': 15},
          'not-a-map', // malformed — should be skipped
        ],
      });
      expect(event.validMoves, hasLength(1));
    });
  });

  // ── equality ───────────────────────────────────────────────────────────────

  group('DiceRolled equality', () {
    const move = ValidMove(pawnIndex: 0, fromPos: 0, toPos: 1);

    test('8 — two instances with same data are equal', () {
      const a = DiceRolled(matchId: kMatchId, color: 'red', value: 6, validMoves: [move]);
      const b = DiceRolled(matchId: kMatchId, color: 'red', value: 6, validMoves: [move]);
      expect(a, equals(b));
    });

    test('9 — different value makes instances unequal', () {
      const a = DiceRolled(matchId: kMatchId, color: 'red', value: 6, validMoves: [move]);
      const b = DiceRolled(matchId: kMatchId, color: 'red', value: 5, validMoves: [move]);
      expect(a, isNot(equals(b)));
    });

    test('10 — different validMoves list makes instances unequal', () {
      const a = DiceRolled(matchId: kMatchId, color: 'red', value: 4, validMoves: [move]);
      const b = DiceRolled(matchId: kMatchId, color: 'red', value: 4, validMoves: []);
      expect(a, isNot(equals(b)));
    });

    test('11 — hashCode matches for equal instances', () {
      const a = DiceRolled(matchId: kMatchId, color: 'blue', value: 3, validMoves: []);
      const b = DiceRolled(matchId: kMatchId, color: 'blue', value: 3, validMoves: []);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ── toString ───────────────────────────────────────────────────────────────

  test('12 — toString contains all required fields', () {
    const event = DiceRolled(matchId: kMatchId, color: 'green', value: 2, validMoves: []);
    final str   = event.toString();
    expect(str, contains(kMatchId));
    expect(str, contains('green'));
    expect(str, contains('2'));
  });
}
