import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/turn_changed.dart';

void main() {
  const kMatchId = 'match-uuid-1';

  // ── fromJson ───────────────────────────────────────────────────────────────

  group('TurnChanged.fromJson', () {
    test('1 — parses a correct payload', () {
      final event = TurnChanged.fromJson({
        'matchId':  kMatchId,
        'nextTurn': 'blue',
      });
      expect(event.matchId,  kMatchId);
      expect(event.nextTurn, 'blue');
    });

    test('2 — parses all valid colour values', () {
      for (final color in ['red', 'blue', 'green', 'yellow']) {
        final event = TurnChanged.fromJson({'matchId': kMatchId, 'nextTurn': color});
        expect(event.nextTurn, color);
      }
    });

    test('3 — throws FormatException when matchId is missing', () {
      expect(
        () => TurnChanged.fromJson({'nextTurn': 'red'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('4 — throws FormatException when nextTurn is missing', () {
      expect(
        () => TurnChanged.fromJson({'matchId': kMatchId}),
        throwsA(isA<FormatException>()),
      );
    });

    test('5 — throws FormatException when both fields are missing', () {
      expect(
        () => TurnChanged.fromJson({}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ── equality ───────────────────────────────────────────────────────────────

  group('TurnChanged equality', () {
    test('6 — two instances with same fields are equal', () {
      const a = TurnChanged(matchId: kMatchId, nextTurn: 'green');
      const b = TurnChanged(matchId: kMatchId, nextTurn: 'green');
      expect(a, equals(b));
    });

    test('7 — different nextTurn makes instances unequal', () {
      const a = TurnChanged(matchId: kMatchId, nextTurn: 'red');
      const b = TurnChanged(matchId: kMatchId, nextTurn: 'blue');
      expect(a, isNot(equals(b)));
    });

    test('8 — different matchId makes instances unequal', () {
      const a = TurnChanged(matchId: 'match-1', nextTurn: 'red');
      const b = TurnChanged(matchId: 'match-2', nextTurn: 'red');
      expect(a, isNot(equals(b)));
    });

    test('9 — hashCode matches for equal instances', () {
      const a = TurnChanged(matchId: kMatchId, nextTurn: 'yellow');
      const b = TurnChanged(matchId: kMatchId, nextTurn: 'yellow');
      expect(a.hashCode, b.hashCode);
    });

    test('10 — is not equal to an object of another type', () {
      const a = TurnChanged(matchId: kMatchId, nextTurn: 'red');
      expect(a, isNot(equals('not-a-turn-changed')));
    });
  });

  // ── toString ───────────────────────────────────────────────────────────────

  test('11 — toString contains matchId and nextTurn', () {
    const event = TurnChanged(matchId: kMatchId, nextTurn: 'yellow');
    final str   = event.toString();
    expect(str, contains(kMatchId));
    expect(str, contains('yellow'));
  });
}
