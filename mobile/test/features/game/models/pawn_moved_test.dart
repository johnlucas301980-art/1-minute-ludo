import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/pawn_moved.dart';

void main() {
  const kMatchId = 'match-uuid-1';

  // ── fromJson ───────────────────────────────────────────────────────────────

  group('PawnMoved.fromJson', () {
    test('1 — parses a payload without capture', () {
      final event = PawnMoved.fromJson({
        'matchId':    kMatchId,
        'color':      'red',
        'pawnIndex':  1,
        'toPosition': 15,
      });
      expect(event.matchId,           kMatchId);
      expect(event.color,             'red');
      expect(event.pawnIndex,         1);
      expect(event.toPosition,        15);
      expect(event.capturedColor,     isNull);
      expect(event.capturedPawnIndex, isNull);
    });

    test('2 — parses a payload with capture', () {
      final event = PawnMoved.fromJson({
        'matchId':           kMatchId,
        'color':             'blue',
        'pawnIndex':         0,
        'toPosition':        30,
        'capturedColor':     'yellow',
        'capturedPawnIndex': 2,
      });
      expect(event.capturedColor,     'yellow');
      expect(event.capturedPawnIndex, 2);
    });

    test('3 — parses when capturedColor is present but capturedPawnIndex is absent',
        () {
      // Unusual but graceful: only capturedColor present.
      final event = PawnMoved.fromJson({
        'matchId':       kMatchId,
        'color':         'green',
        'pawnIndex':     3,
        'toPosition':    20,
        'capturedColor': 'red',
      });
      expect(event.capturedColor,     'red');
      expect(event.capturedPawnIndex, isNull);
    });

    test('4 — throws FormatException when matchId is missing', () {
      expect(
        () => PawnMoved.fromJson(
            {'color': 'red', 'pawnIndex': 0, 'toPosition': 10}),
        throwsA(isA<FormatException>()),
      );
    });

    test('5 — throws FormatException when pawnIndex is a string', () {
      expect(
        () => PawnMoved.fromJson({
          'matchId':    kMatchId,
          'color':      'red',
          'pawnIndex':  '0',
          'toPosition': 10,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('6 — throws FormatException when toPosition is missing', () {
      expect(
        () => PawnMoved.fromJson(
            {'matchId': kMatchId, 'color': 'red', 'pawnIndex': 0}),
        throwsA(isA<FormatException>()),
      );
    });

    test('7 — toPosition of 57 (HOME_FINISHED) is parsed correctly', () {
      final event = PawnMoved.fromJson({
        'matchId':    kMatchId,
        'color':      'yellow',
        'pawnIndex':  2,
        'toPosition': 57,
      });
      expect(event.toPosition, 57);
    });
  });

  // ── equality ───────────────────────────────────────────────────────────────

  group('PawnMoved equality', () {
    test('8 — two instances without capture and same fields are equal', () {
      const a = PawnMoved(matchId: kMatchId, color: 'red', pawnIndex: 0, toPosition: 10);
      const b = PawnMoved(matchId: kMatchId, color: 'red', pawnIndex: 0, toPosition: 10);
      expect(a, equals(b));
    });

    test('9 — two instances with same capture fields are equal', () {
      const a = PawnMoved(
        matchId: kMatchId, color: 'blue', pawnIndex: 1, toPosition: 20,
        capturedColor: 'red', capturedPawnIndex: 3,
      );
      const b = PawnMoved(
        matchId: kMatchId, color: 'blue', pawnIndex: 1, toPosition: 20,
        capturedColor: 'red', capturedPawnIndex: 3,
      );
      expect(a, equals(b));
    });

    test('10 — different capturedColor makes instances unequal', () {
      const a = PawnMoved(
        matchId: kMatchId, color: 'blue', pawnIndex: 1, toPosition: 20,
        capturedColor: 'red',
      );
      const b = PawnMoved(
        matchId: kMatchId, color: 'blue', pawnIndex: 1, toPosition: 20,
        capturedColor: 'green',
      );
      expect(a, isNot(equals(b)));
    });

    test('11 — null vs non-null capturedColor makes instances unequal', () {
      const a = PawnMoved(matchId: kMatchId, color: 'red', pawnIndex: 0, toPosition: 5);
      const b = PawnMoved(
        matchId: kMatchId, color: 'red', pawnIndex: 0, toPosition: 5,
        capturedColor: 'blue',
      );
      expect(a, isNot(equals(b)));
    });

    test('12 — hashCode matches for equal instances', () {
      const a = PawnMoved(matchId: kMatchId, color: 'green', pawnIndex: 2, toPosition: 30);
      const b = PawnMoved(matchId: kMatchId, color: 'green', pawnIndex: 2, toPosition: 30);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ── toString ───────────────────────────────────────────────────────────────

  test('13 — toString includes all fields including capture fields', () {
    const event = PawnMoved(
      matchId:           kMatchId,
      color:             'yellow',
      pawnIndex:         3,
      toPosition:        40,
      capturedColor:     'green',
      capturedPawnIndex: 1,
    );
    final str = event.toString();
    expect(str, contains(kMatchId));
    expect(str, contains('yellow'));
    expect(str, contains('3'));
    expect(str, contains('40'));
    expect(str, contains('green'));
    expect(str, contains('1'));
  });
}
