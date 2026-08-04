import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ─── Classic layout: Red=BL, Blue=TL, Yellow=TR, Green=BR ────────────────────

// Premium board palette
const Color _kRedFill    = Color(0xFFE53935);
const Color _kBlueFill   = Color(0xFF1565C0);
const Color _kYellowFill = Color(0xFFF9A825);
const Color _kGreenFill  = Color(0xFF2E7D32);

const Color _kRedLight    = Color(0xFFFFCDD2);
const Color _kBlueLight   = Color(0xFFBBDEFB);
const Color _kYellowLight = Color(0xFFFFF9C4);
const Color _kGreenLight  = Color(0xFFC8E6C9);

const Color _kWhite   = Color(0xFFFFFFFF);
const Color _kBorder  = Color(0xFF424242);
const Color _kStar    = Color(0xFFFF6F00);
const Color _kBgBoard = Color(0xFFF5F5F0);

// ─── Track cells (15×15, Red enters at BL, clockwise) ────────────────────────
//
// Classic layout — Red at bottom-left (abs 0), Blue at top-left (abs 15),
// Yellow at top-right (abs 41 as measured), Green at bottom-right (abs 28).
//
// Path: from (8,1) going UP the left arm, across the top row (right),
//       down the right arm, across the bottom row (left), back up.
const List<(int, int)> kPremiumTrackCells = [
  // ── Red entry: up left arm ────────────────────────────────────────────────
  (8,  1), (7,  1), (6,  1), (5,  1), (4,  1), (3,  1), // abs  0– 5
  (2,  1), (1,  1),                                       // abs  6– 7
  // ── Top-left corner, right along top ─────────────────────────────────────
  (0,  1), (0,  2), (0,  3), (0,  4), (0,  5), (0,  6),  // abs  8–13
  (0,  7),                                                 // abs 14
  // ── Blue entry: right along top into TR yard ──────────────────────────────
  (0,  8), (0,  9), (0, 10), (0, 11), (0, 12), (0, 13),  // abs 15–20
  // ── Down right arm ───────────────────────────────────────────────────────
  (1, 13), (2, 13), (3, 13), (4, 13), (5, 13),            // abs 21–25
  (6, 13), (7, 13),                                        // abs 26–27
  // ── Green entry: down right arm into BR yard ─────────────────────────────
  (8, 13), (9, 13), (10, 13), (11, 13), (12, 13),         // abs 28–32
  (13, 13), (14, 13),                                      // abs 33–34
  // ── Bottom-right corner, left along bottom ───────────────────────────────
  (14, 12), (14, 11), (14, 10), (14, 9), (14, 8),         // abs 35–39
  (14,  7),                                                // abs 40
  // ── Yellow entry: left along bottom toward BL yard ───────────────────────
  (14,  6), (14,  5), (14,  4), (14,  3), (14,  2),       // abs 41–45
  (14,  1),                                                // abs 46
  // ── Up left side back to Red ──────────────────────────────────────────────
  (13,  1), (12,  1), (11,  1), (10,  1), (9,  1),        // abs 47–51
];

// Home column cells: 5 cells leading toward the center (positions 52–56).
// Red   (BL) → up col 7 from row 13 to row 9
// Blue  (TL) → right row 7 from col 1 to col 5
// Yellow(TR) → down col 7 from row 1 to row 5
// Green (BR) → left row 7 from col 13 to col 9
const Map<String, List<(int, int)>> kPremiumHomeCells = {
  'red':    [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
  'blue':   [(7,  1), (7,  2), (7,  3), (7,  4), (7,  5)],
  'yellow': [(1,  7), (2,  7), (3,  7), (4,  7), (5,  7)],
  'green':  [(7, 13), (7, 12), (7, 11), (7, 10), (7,  9)],
};

// Safe squares (absolute positions): colour entries + 4 mid-arm stars.
// Red(0), star(8), Blue(15), star(21), Green(28), star(35), Yellow(41), star(47)
const Set<int> kPremiumSafePositions = {0, 8, 15, 21, 28, 35, 41, 47};

// ─── PremiumLudoBoardWidget ───────────────────────────────────────────────────

/// Production-quality Ludo board with:
///   Red = Bottom-Left, Blue = Top-Left,
///   Yellow = Top-Right, Green = Bottom-Right.
///
/// Parameters
///   [boardSize]     — side length in logical pixels.
///   [activeColors]  — active yard colours (drives dim inactive yards).
///   [pawnCount]     — pawns per player (1–4), default 4.
///   [rotation]      — board rotation in radians so myColor is at BL.
///                     0=red, π/2=green, π=yellow, -π/2=blue.
class PremiumLudoBoardWidget extends StatelessWidget {
  const PremiumLudoBoardWidget({
    super.key,
    this.boardSize = 360.0,
    this.activeColors,
    this.pawnCount = 4,
    this.rotation = 0.0,
  });

  final double boardSize;
  final List<String>? activeColors;
  final int pawnCount;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final board = SizedBox(
      width: boardSize,
      height: boardSize,
      child: CustomPaint(
        size: Size(boardSize, boardSize),
        painter: _PremiumBoardPainter(
          boardSize:    boardSize,
          activeColors: activeColors,
          pawnCount:    pawnCount,
        ),
      ),
    );

    if (rotation == 0.0) return board;
    return Transform.rotate(angle: rotation, child: board);
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _PremiumBoardPainter extends CustomPainter {
  _PremiumBoardPainter({
    required this.boardSize,
    this.activeColors,
    this.pawnCount = 4,
  });

  final double boardSize;
  final List<String>? activeColors;
  final int pawnCount;

  double get _cs => boardSize / 15;

  Rect _cell(int row, int col) {
    final cs = _cs;
    return Rect.fromLTWH(col * cs, row * cs, cs, cs);
  }

  Rect _cellTuple((int, int) rc) => _cell(rc.$1, rc.$2);

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  Paint _stroke(Color color, [double width = 0.5]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas);
    _drawYards(canvas);
    _drawHomePaths(canvas);
    _drawCenter(canvas);
    _drawSafeMarkers(canvas);
    _drawGrid(canvas);
    _drawYardPawns(canvas);
    _drawOuterBorder(canvas);
  }

  // 1. Background
  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, boardSize, boardSize),
      _fill(_kBgBoard),
    );
  }

  // 2. Corner yards
  void _drawYards(Canvas canvas) {
    final active = activeColors ?? ['red', 'blue', 'yellow', 'green'];
    // Red   = bottom-left:  startRow=9, startCol=0
    // Blue  = top-left:     startRow=0, startCol=0
    // Yellow= top-right:    startRow=0, startCol=9
    // Green = bottom-right: startRow=9, startCol=9
    _drawOneYard(canvas, startRow: 9, startCol: 0, color: _kRedFill,
        lightColor: _kRedLight,    isActive: active.contains('red'));
    _drawOneYard(canvas, startRow: 0, startCol: 0, color: _kBlueFill,
        lightColor: _kBlueLight,   isActive: active.contains('blue'));
    _drawOneYard(canvas, startRow: 0, startCol: 9, color: _kYellowFill,
        lightColor: _kYellowLight, isActive: active.contains('yellow'));
    _drawOneYard(canvas, startRow: 9, startCol: 9, color: _kGreenFill,
        lightColor: _kGreenLight,  isActive: active.contains('green'));
  }

  void _drawOneYard(
    Canvas canvas, {
    required int startRow,
    required int startCol,
    required Color color,
    required Color lightColor,
    required bool isActive,
  }) {
    final cs = _cs;
    final displayColor = isActive ? color : const Color(0xFF616161);
    final outerRect = Rect.fromLTWH(
      startCol * cs, startRow * cs, 6 * cs, 6 * cs,
    );
    final innerRect = Rect.fromLTWH(
      (startCol + 1) * cs, (startRow + 1) * cs, 4 * cs, 4 * cs,
    );

    // Outer coloured square
    canvas.drawRect(outerRect, _fill(displayColor));

    // Premium highlight on top edge
    if (isActive) {
      final highlightPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(startCol * cs, startRow * cs),
          Offset(startCol * cs, (startRow + 1.5) * cs),
          [color.withAlpha(160), color.withAlpha(0)],
        );
      canvas.drawRect(outerRect, highlightPaint);
    }

    // Inner white/light rounded area
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        innerRect,
        Radius.circular(cs * 0.3),
      ),
      _fill(isActive ? lightColor.withAlpha(240) : const Color(0xFF2A2A2A)),
    );

    // Subtle inner border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        innerRect,
        Radius.circular(cs * 0.3),
      ),
      _stroke(displayColor.withAlpha(isActive ? 180 : 100), 1.0),
    );

    // Pawn placeholder circles
    final double r = cs * 0.40;
    final spots = _yardSpots(pawnCount, startRow, startCol, cs);
    for (final spot in spots) {
      // Shadow
      canvas.drawCircle(
        spot + const Offset(1, 1.5),
        r,
        _fill(Colors.black.withAlpha(isActive ? 50 : 20)),
      );
      // Circle body
      canvas.drawCircle(spot, r, _fill(displayColor.withAlpha(isActive ? 200 : 80)));
      // White inner shine
      if (isActive) {
        canvas.drawCircle(
          spot - Offset(r * 0.2, r * 0.25),
          r * 0.35,
          _fill(Colors.white.withAlpha(70)),
        );
      }
      // Border
      canvas.drawCircle(
        spot, r, _stroke(displayColor.withAlpha(isActive ? 230 : 120), 1.5),
      );
    }

    // Inactive dim overlay
    if (!isActive) {
      canvas.drawRect(outerRect, _fill(Colors.black.withAlpha(100)));
    }
  }

  static List<Offset> _yardSpots(
    int pawnCount, int startRow, int startCol, double cs,
  ) {
    switch (pawnCount) {
      case 1:
        return [Offset((startCol + 2.5) * cs, (startRow + 2.5) * cs)];
      case 2:
        return [
          Offset((startCol + 1.5) * cs, (startRow + 2.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 2.5) * cs),
        ];
      case 3:
        return [
          Offset((startCol + 2.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 1.5) * cs, (startRow + 3.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 3.5) * cs),
        ];
      default:
        return [
          Offset((startCol + 1.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 1.5) * cs, (startRow + 3.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 3.5) * cs),
        ];
    }
  }

  // 3. Coloured home paths
  void _drawHomePaths(Canvas canvas) {
    const lightColors = {
      'red':    _kRedLight,
      'blue':   _kBlueLight,
      'yellow': _kYellowLight,
      'green':  _kGreenLight,
    };
    const deepColors = {
      'red':    _kRedFill,
      'blue':   _kBlueFill,
      'yellow': _kYellowFill,
      'green':  _kGreenFill,
    };
    kPremiumHomeCells.forEach((colour, cells) {
      final light = lightColors[colour]!;
      final deep  = deepColors[colour]!;
      for (final rc in cells) {
        canvas.drawRect(_cellTuple(rc), _fill(light));
        // Subtle centre stripe accent
        final r = _cellTuple(rc);
        canvas.drawRect(
          r.deflate(_cs * 0.25),
          _fill(deep.withAlpha(40)),
        );
      }
    });
  }

  // 4. Centre 3×3 finishing area with 4 coloured triangles
  void _drawCenter(Canvas canvas) {
    final cs = _cs;
    // 3×3 centre: rows 6–8, cols 6–8
    final tl = Offset(6 * cs, 6 * cs);
    final tr = Offset(9 * cs, 6 * cs);
    final bl = Offset(6 * cs, 9 * cs);
    final br = Offset(9 * cs, 9 * cs);
    final cx = Offset(7.5 * cs, 7.5 * cs);

    // New layout:
    // Blue  (TL) approaches from the left  → left triangle
    // Yellow(TR) approaches from the top   → top triangle
    // Green (BR) approaches from the right → right triangle
    // Red   (BL) approaches from the bottom→ bottom triangle
    _drawTriangle(canvas, tl, bl, cx, _kBlueFill.withAlpha(220));
    _drawTriangle(canvas, tl, tr, cx, _kYellowFill.withAlpha(220));
    _drawTriangle(canvas, tr, br, cx, _kGreenFill.withAlpha(220));
    _drawTriangle(canvas, bl, br, cx, _kRedFill.withAlpha(220));

    // Centre finishing star circle
    final starR = cs * 0.60;
    canvas.drawCircle(cx, starR, _fill(_kWhite));
    canvas.drawCircle(cx, starR, _stroke(const Color(0xFFBDBDBD), 1.0));
    _drawStarPath(canvas, cx, starR * 0.82, 5, _kStar);
  }

  void _drawTriangle(Canvas canvas, Offset a, Offset b, Offset c, Color color) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    canvas.drawPath(path, _fill(color));
  }

  // 5. Safe-square star markers
  void _drawSafeMarkers(Canvas canvas) {
    for (final absPos in kPremiumSafePositions) {
      final rect   = _cellTuple(kPremiumTrackCells[absPos]);
      final centre = rect.center;
      final r      = _cs * 0.34;
      canvas.drawCircle(centre, r, _fill(_kStar.withAlpha(30)));
      _drawStarPath(canvas, centre, r, 5, _kStar);
    }
  }

  // 6. Grid lines
  void _drawGrid(Canvas canvas) {
    final cs    = _cs;
    final paint = _stroke(_kBorder.withAlpha(70), 0.3);
    for (var i = 0; i <= 15; i++) {
      final t = i * cs;
      canvas.drawLine(Offset(t, 0), Offset(t, boardSize), paint);
      canvas.drawLine(Offset(0, t), Offset(boardSize, t), paint);
    }
  }

  // 7. Yard pawn placeholders (small circles showing all pawns in yards)
  void _drawYardPawns(Canvas canvas) {
    // Already drawn in _drawOneYard — this method intentionally left as hook
    // for future positioned-pawn rendering.
  }

  // 8. Outer border with premium double-line treatment
  void _drawOuterBorder(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, boardSize, boardSize),
      _stroke(_kBorder, 2.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(2, 2, boardSize - 4, boardSize - 4),
      _stroke(_kBorder.withAlpha(60), 1.0),
    );
  }

  // Star helper
  void _drawStarPath(
    Canvas canvas, Offset centre, double outerR, int points, Color color,
  ) {
    final innerR = outerR * 0.42;
    final path   = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r     = i.isEven ? outerR : innerR;
      final x     = centre.dx + r * math.cos(angle);
      final y     = centre.dy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y) ; else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, _fill(color));
  }

  @override
  bool shouldRepaint(_PremiumBoardPainter old) =>
      old.boardSize    != boardSize    ||
      old.activeColors != activeColors ||
      old.pawnCount    != pawnCount;
}
