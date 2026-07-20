import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/ludo_path.dart';
import 'package:one_minute_ludo/features/game/widgets/ludo_board_widget.dart';

// ─── Pump helper ─────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  double boardSize = 360.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: LudoBoardWidget(boardSize: boardSize),
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── Widget tests ──────────────────────────────────────────────────────────

  group('LudoBoardWidget — widget', () {
    testWidgets('1 — smoke: renders without error', (tester) async {
      await _pump(tester);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
    });

    testWidgets('2 — default boardSize is 360 × 360', (tester) async {
      await _pump(tester);
      final box =
          tester.renderObject<RenderBox>(find.byType(LudoBoardWidget));
      expect(box.size.width,  360.0);
      expect(box.size.height, 360.0);
    });

    testWidgets('3 — accepts custom boardSize 480', (tester) async {
      await _pump(tester, boardSize: 480.0);
      final box =
          tester.renderObject<RenderBox>(find.byType(LudoBoardWidget));
      expect(box.size.width,  480.0);
      expect(box.size.height, 480.0);
    });

    testWidgets('4 — square: width equals height for any boardSize',
        (tester) async {
      await _pump(tester, boardSize: 270.0);
      final box =
          tester.renderObject<RenderBox>(find.byType(LudoBoardWidget));
      expect(box.size.width, box.size.height);
    });

    testWidgets('5 — contains exactly one CustomPaint', (tester) async {
      await _pump(tester);
      // Scope to LudoBoardWidget descendants only; Scaffold also uses CustomPaint.
      expect(
        find.descendant(
          of: find.byType(LudoBoardWidget),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('6 — key is forwarded to the widget', (tester) async {
      const key = Key('ludo_board');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LudoBoardWidget(key: key),
            ),
          ),
        ),
      );
      expect(find.byKey(key), findsOneWidget);
    });

    testWidgets('7 — renders with small boardSize (90)', (tester) async {
      await _pump(tester, boardSize: 90.0);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
    });

    testWidgets('8 — renders with large boardSize (600)', (tester) async {
      await _pump(tester, boardSize: 600.0);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
    });

    testWidgets('9 — no overflow errors at default size', (tester) async {
      await _pump(tester);
      // pumpAndSettle to catch any layout errors emitted asynchronously.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── Coordinate data tests ─────────────────────────────────────────────────

  group('LudoBoardWidget — kTrackCells', () {
    test('10 — kTrackCells has exactly 52 entries', () {
      expect(kTrackCells.length, 52);
    });

    test('11 — kTrackCells contains no duplicate cells', () {
      final unique = kTrackCells.toSet();
      expect(unique.length, 52,
          reason: 'every track cell must be unique');
    });

    test('12 — all cells are within the 15 × 15 grid', () {
      for (var i = 0; i < kTrackCells.length; i++) {
        final (r, c) = kTrackCells[i];
        expect(r, inInclusiveRange(0, 14),
            reason: 'abs $i row $r out of range');
        expect(c, inInclusiveRange(0, 14),
            reason: 'abs $i col $c out of range');
      }
    });

    test('13 — each cell is adjacent (distance 1) to the next', () {
      for (var i = 0; i < kTrackCells.length; i++) {
        final (r1, c1) = kTrackCells[i];
        final (r2, c2) = kTrackCells[(i + 1) % kTrackCells.length];
        final dist = (r2 - r1).abs() + (c2 - c1).abs();
        expect(dist, 1,
            reason:
                'abs $i → ${(i + 1) % 52}: ($r1,$c1) → ($r2,$c2) distance $dist ≠ 1');
      }
    });

    test('14 — Red entry (abs 0) matches colorEntryOffset', () {
      final offset = colorEntryOffset['red']!;
      expect(kTrackCells[offset], (6, 1));
    });

    test('15 — Blue entry (abs 13) matches colorEntryOffset', () {
      final offset = colorEntryOffset['blue']!;
      expect(kTrackCells[offset], (0, 8));
    });

    test('16 — Green entry (abs 26) matches colorEntryOffset', () {
      final offset = colorEntryOffset['green']!;
      expect(kTrackCells[offset], (8, 13));
    });

    test('17 — Yellow entry (abs 39) matches colorEntryOffset', () {
      final offset = colorEntryOffset['yellow']!;
      expect(kTrackCells[offset], (14, 6));
    });

    test('18 — all 8 safeAbsolutePositions are valid indices', () {
      for (final absPos in safeAbsolutePositions) {
        expect(absPos, inInclusiveRange(0, 51),
            reason: 'safe pos $absPos out of track range');
      }
    });

    test('19 — star safe squares are 8 steps from each entry square', () {
      for (final entry in colorEntryOffset.entries) {
        final entryAbs = entry.value;
        final starAbs  = (entryAbs + 8) % trackLength;
        expect(safeAbsolutePositions.contains(starAbs), isTrue,
            reason:
                '${entry.key} entry+8 = $starAbs should be a safe square');
      }
    });
  });

  // ── Home column data tests ────────────────────────────────────────────────

  group('LudoBoardWidget — kHomeCells', () {
    test('20 — kHomeCells has entries for all four colours', () {
      expect(kHomeCells.keys,
          containsAll(['red', 'blue', 'green', 'yellow']));
    });

    test('21 — each colour home path has exactly 5 cells', () {
      for (final entry in kHomeCells.entries) {
        expect(entry.value.length, 5,
            reason: '${entry.key} home path must have 5 cells');
      }
    });

    test('22 — home path cells do not overlap with main track', () {
      final trackSet = kTrackCells.toSet();
      kHomeCells.forEach((colour, cells) {
        for (final rc in cells) {
          expect(trackSet.contains(rc), isFalse,
              reason:
                  '$colour home cell $rc must not appear on the main track');
        }
      });
    });

    test('23 — home path cells are within the 15 × 15 grid', () {
      kHomeCells.forEach((colour, cells) {
        for (final (r, c) in cells) {
          expect(r, inInclusiveRange(0, 14),
              reason: '$colour home row $r out of range');
          expect(c, inInclusiveRange(0, 14),
              reason: '$colour home col $c out of range');
        }
      });
    });

    test('24 — Red home path is adjacent to track cell abs 51', () {
      // Red pawn at abs 51 (7,1) steps right into rel-52 (7,2).
      final abs51     = kTrackCells[51];
      final firstHome = kHomeCells['red']![0];
      final (r1, c1)  = abs51;
      final (r2, c2)  = firstHome;
      final dist      = (r2 - r1).abs() + (c2 - c1).abs();
      expect(dist, 1,
          reason: 'Red track→home entry must be adjacent');
    });

    test('25 — Blue home path is adjacent to track cell abs 12', () {
      // Blue pawn at abs 12 (0,7) steps down into rel-52 (1,7).
      final abs12     = kTrackCells[12];
      final firstHome = kHomeCells['blue']![0];
      final (r1, c1)  = abs12;
      final (r2, c2)  = firstHome;
      final dist      = (r2 - r1).abs() + (c2 - c1).abs();
      expect(dist, 1,
          reason: 'Blue track→home entry must be adjacent');
    });

    test('26 — Green home path is adjacent to track cell abs 25', () {
      // Green pawn at abs 25 (7,13) steps left into rel-52 (7,12).
      final abs25     = kTrackCells[25];
      final firstHome = kHomeCells['green']![0];
      final (r1, c1)  = abs25;
      final (r2, c2)  = firstHome;
      final dist      = (r2 - r1).abs() + (c2 - c1).abs();
      expect(dist, 1,
          reason: 'Green track→home entry must be adjacent');
    });

    test('27 — Yellow home path is adjacent to track cell abs 38', () {
      // Yellow pawn at abs 38 (14,7) steps up into rel-52 (13,7).
      final abs38     = kTrackCells[38];
      final firstHome = kHomeCells['yellow']![0];
      final (r1, c1)  = abs38;
      final (r2, c2)  = firstHome;
      final dist      = (r2 - r1).abs() + (c2 - c1).abs();
      expect(dist, 1,
          reason: 'Yellow track→home entry must be adjacent');
    });
  });
}
