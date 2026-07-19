import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/valid_move.dart';

void main() {
  // ── fromJson ───────────────────────────────────────────────────────────────

  group('ValidMove.fromJson', () {
    test('1 — parses a correct payload', () {
      final move = ValidMove.fromJson({
        'pawnIndex': 2,
        'fromPos':   0,
        'toPos':     1,
      });
      expect(move.pawnIndex, 2);
      expect(move.fromPos,   0);
      expect(move.toPos,     1);
    });

    test('2 — parses non-zero fromPos and large toPos', () {
      final move = ValidMove.fromJson({
        'pawnIndex': 0,
        'fromPos':   45,
        'toPos':     51,
      });
      expect(move.pawnIndex, 0);
      expect(move.fromPos,   45);
      expect(move.toPos,     51);
    });

    test('3 — throws FormatException when pawnIndex is missing', () {
      expect(
        () => ValidMove.fromJson({'fromPos': 1, 'toPos': 5}),
        throwsA(isA<FormatException>()),
      );
    });

    test('4 — throws FormatException when fromPos is a string', () {
      expect(
        () => ValidMove.fromJson({'pawnIndex': 0, 'fromPos': '0', 'toPos': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('5 — throws FormatException when toPos is missing', () {
      expect(
        () => ValidMove.fromJson({'pawnIndex': 1, 'fromPos': 5}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ── equality ───────────────────────────────────────────────────────────────

  group('ValidMove equality', () {
    test('6 — two instances with same fields are equal', () {
      const a = ValidMove(pawnIndex: 1, fromPos: 10, toPos: 16);
      const b = ValidMove(pawnIndex: 1, fromPos: 10, toPos: 16);
      expect(a, equals(b));
    });

    test('7 — instances with different pawnIndex are not equal', () {
      const a = ValidMove(pawnIndex: 0, fromPos: 10, toPos: 16);
      const b = ValidMove(pawnIndex: 1, fromPos: 10, toPos: 16);
      expect(a, isNot(equals(b)));
    });

    test('8 — instances with different toPos are not equal', () {
      const a = ValidMove(pawnIndex: 0, fromPos: 10, toPos: 16);
      const b = ValidMove(pawnIndex: 0, fromPos: 10, toPos: 17);
      expect(a, isNot(equals(b)));
    });

    test('9 — hashCode matches for equal instances', () {
      const a = ValidMove(pawnIndex: 3, fromPos: 0, toPos: 1);
      const b = ValidMove(pawnIndex: 3, fromPos: 0, toPos: 1);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ── toString ───────────────────────────────────────────────────────────────

  test('10 — toString includes all fields', () {
    const move = ValidMove(pawnIndex: 2, fromPos: 5, toPos: 11);
    final str  = move.toString();
    expect(str, contains('pawnIndex: 2'));
    expect(str, contains('fromPos: 5'));
    expect(str, contains('toPos: 11'));
  });
}
