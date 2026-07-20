import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ludo_path.dart';

// ─── Board palette ────────────────────────────────────────────────────────────

const Color _kRedFill    = Color(0xFFE53935);
const Color _kBlueFill   = Color(0xFF1E88E5);
const Color _kGreenFill  = Color(0xFF43A047);
const Color _kYellowFill = Color(0xFFFDD835);

const Color _kRedLight    = Color(0xFFFFCDD2);
const Color _kBlueLight   = Color(0xFFBBDEFB);
const Color _kGreenLight  = Color(0xFFC8E6C9);
const Color _kYellowLight = Color(0xFFFFF9C4);

const Color _kWhite  = Color(0xFFFFFFFF);
const Color _kBorder = Color(0xFF757575);
const Color _kStar   = Color(0xFFFF6F00); // safe-square star colour

// ─── Track coordinate table ───────────────────────────────────────────────────

/// 52 absolute track positions → (row, col) on the 15 × 15 grid.
///
/// The path goes clockwise starting from Red's entry square (absolute 0).
///
/// Entry squares (colour offsets from [colorEntryOffset]):
///   Red   (abs  0) → (6,  1)
///   Blue  (abs 13) → (0,  8)
///   Green (abs 26) → (8, 13)
///   Yellow(abs 39) → (14, 6)
///
/// Safe squares ([safeAbsolutePositions]): abs 0,8,13,21,26,34,39,47.
const List<(int, int)> kTrackCells = [
  // ── Side 1: up col 1, then right row 0 (Red entry abs 0) ──────────────────
  (6, 1), (5, 1), (4, 1), (3, 1), (2, 1), (1, 1),          // abs  0– 5
  (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7),  // abs  6–12
  // ── Side 2: right row 0, then down col 13 (Blue entry abs 13) ─────────────
  (0, 8), (0, 9), (0, 10), (0, 11), (0, 12), (0, 13),       // abs 13–18
  (1, 13), (2, 13), (3, 13), (4, 13), (5, 13),              // abs 19–23
  (6, 13), (7, 13),                                          // abs 24–25
  // ── Side 3: down col 13, then left row 14 (Green entry abs 26) ────────────
  (8, 13), (9, 13), (10, 13), (11, 13), (12, 13),           // abs 26–30
  (13, 13), (14, 13),                                        // abs 31–32
  (14, 12), (14, 11), (14, 10), (14, 9), (14, 8), (14, 7),  // abs 33–38
  // ── Side 4: left row 14, then up col 1 (Yellow entry abs 39) ─────────────
  (14, 6), (14, 5), (14, 4), (14, 3), (14, 2), (14, 1),     // abs 39–44
  (13, 1), (12, 1), (11, 1), (10, 1), (9, 1),               // abs 45–49
  (8, 1),  (7, 1),                                           // abs 50–51
];

/// Home column cells for each colour, in colour-relative order relPos 52 → 56.
///
/// Each list has exactly 5 entries leading toward the finishing centre.
/// Home columns are in the middle row/column of each cross arm:
///   Red    → row 7,  cols 2–6   (going right toward centre)
///   Blue   → col 7,  rows 1–5   (going down  toward centre)
///   Green  → row 7,  cols 12–8  (going left  toward centre)
///   Yellow → col 7,  rows 13–9  (going up    toward centre)
const Map<String, List<(int, int)>> kHomeCells = {
  'red':    [(7, 2), (7, 3), (7, 4), (7, 5), (7, 6)],
  'blue':   [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
  'green':  [(7, 12), (7, 11), (7, 10), (7, 9), (7, 8)],
  'yellow': [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
};

// ─── LudoBoardWidget ─────────────────────────────────────────────────────────

/// Static 15 × 15 Ludo board — Phase 6.4B.
///
/// Renders:
///  - Full board grid (15 × 15)
///  - Four coloured home yards with inner pawn-placeholder circles
///  - Coloured home paths (middle row/col of each cross arm)
///  - Centre finishing area (four coloured triangles)
///  - Safe-square star markers on the 8 [safeAbsolutePositions]
///
/// **Not implemented in this phase:**
///   pawns, pawn movement, valid-move highlights, onPawnTap, GameScreen
///   changes, MainShell changes, GameService changes.
///
/// Accepts an optional [boardSize] (defaults to 360 logical pixels).
class LudoBoardWidget extends StatelessWidget {
  const LudoBoardWidget({
    super.key,
    this.boardSize = 360.0,
  });

  /// Side length of the board in logical pixels.  Must be positive.
  final double boardSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: CustomPaint(
        size: Size(boardSize, boardSize),
        painter: _LudoBoardPainter(boardSize: boardSize),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter({required this.boardSize});

  final double boardSize;

  double get _cs => boardSize / 15;

  // ── Pixel rect helpers ────────────────────────────────────────────────────

  Rect _cell(int row, int col) {
    final cs = _cs;
    return Rect.fromLTWH(col * cs, row * cs, cs, cs);
  }

  Rect _cellTuple((int, int) rc) => _cell(rc.$1, rc.$2);

  // ── Paint factories ───────────────────────────────────────────────────────

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  Paint _stroke(Color color, [double width = 0.5]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  // ── Main paint sequence ───────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas);
    _drawYards(canvas);
    _drawHomePaths(canvas);
    _drawCenter(canvas);
    _drawSafeMarkers(canvas);
    _drawGrid(canvas);
    _drawOuterBorder(canvas);
  }

  // ── 1. White background ───────────────────────────────────────────────────

  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, boardSize, boardSize),
      _fill(_kWhite),
    );
  }

  // ── 2. Corner yard areas ──────────────────────────────────────────────────

  void _drawYards(Canvas canvas) {
    _drawOneYard(canvas, startRow: 0, startCol: 0,  color: _kRedFill);
    _drawOneYard(canvas, startRow: 0, startCol: 9,  color: _kBlueFill);
    _drawOneYard(canvas, startRow: 9, startCol: 9,  color: _kGreenFill);
    _drawOneYard(canvas, startRow: 9, startCol: 0,  color: _kYellowFill);
  }

  void _drawOneYard(
    Canvas canvas, {
    required int startRow,
    required int startCol,
    required Color color,
  }) {
    final cs = _cs;

    // Outer 6 × 6 coloured rectangle.
    canvas.drawRect(
      Rect.fromLTWH(startCol * cs, startRow * cs, 6 * cs, 6 * cs),
      _fill(color),
    );

    // Inner 4 × 4 white area (inset by 1 cell on each side).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (startCol + 1) * cs,
          (startRow + 1) * cs,
          4 * cs,
          4 * cs,
        ),
        Radius.circular(cs * 0.25),
      ),
      _fill(_kWhite),
    );

    // Four pawn-placeholder circles at the four sub-quadrant centres.
    final double r = cs * 0.42;
    final List<Offset> spots = [
      Offset((startCol + 1.5) * cs, (startRow + 1.5) * cs),
      Offset((startCol + 3.5) * cs, (startRow + 1.5) * cs),
      Offset((startCol + 1.5) * cs, (startRow + 3.5) * cs),
      Offset((startCol + 3.5) * cs, (startRow + 3.5) * cs),
    ];
    for (final spot in spots) {
      canvas.drawCircle(spot, r, _fill(color.withAlpha(180)));
      canvas.drawCircle(spot, r, _stroke(color.withAlpha(220), 1.2));
    }
  }

  // ── 3. Coloured home paths ────────────────────────────────────────────────

  void _drawHomePaths(Canvas canvas) {
    const colours = {
      'red':    _kRedLight,
      'blue':   _kBlueLight,
      'green':  _kGreenLight,
      'yellow': _kYellowLight,
    };
    kHomeCells.forEach((colour, cells) {
      final fill = colours[colour]!;
      for (final rc in cells) {
        canvas.drawRect(_cellTuple(rc), _fill(fill));
      }
    });
  }

  // ── 4. Centre finishing area (4 coloured triangles) ───────────────────────

  void _drawCenter(Canvas canvas) {
    final cs = _cs;

    // The 3 × 3 centre occupies rows 6–8, cols 6–8.
    final tl = Offset(6 * cs, 6 * cs); // pixel top-left of centre area
    final tr = Offset(9 * cs, 6 * cs); // pixel top-right
    final bl = Offset(6 * cs, 9 * cs); // pixel bottom-left
    final br = Offset(9 * cs, 9 * cs); // pixel bottom-right
    final cx = Offset(7.5 * cs, 7.5 * cs); // exact pixel centre

    // Left  → Red   (Red approaches from the left)
    _drawTriangle(canvas, tl, bl, cx, _kRedFill.withAlpha(210));
    // Top   → Blue  (Blue approaches from the top)
    _drawTriangle(canvas, tl, tr, cx, _kBlueFill.withAlpha(210));
    // Right → Green (Green approaches from the right)
    _drawTriangle(canvas, tr, br, cx, _kGreenFill.withAlpha(210));
    // Bottom→ Yellow(Yellow approaches from the bottom)
    _drawTriangle(canvas, bl, br, cx, _kYellowFill.withAlpha(210));

    // White inner circle with a finishing star.
    final starR = cs * 0.55;
    canvas.drawCircle(cx, starR, _fill(_kWhite));
    _drawStarPath(canvas, cx, starR * 0.85, 5, _kStar);
  }

  void _drawTriangle(
    Canvas canvas,
    Offset a,
    Offset b,
    Offset c,
    Color color,
  ) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    canvas.drawPath(path, _fill(color));
  }

  // ── 5. Safe-square star markers ───────────────────────────────────────────

  void _drawSafeMarkers(Canvas canvas) {
    for (final absPos in safeAbsolutePositions) {
      final rect   = _cellTuple(kTrackCells[absPos]);
      final centre = rect.center;
      final r      = _cs * 0.36;
      // Soft background circle.
      canvas.drawCircle(centre, r, _fill(_kStar.withAlpha(35)));
      // Star glyph.
      _drawStarPath(canvas, centre, r, 5, _kStar);
    }
  }

  // ── 6. Grid lines ─────────────────────────────────────────────────────────

  void _drawGrid(Canvas canvas) {
    final cs    = _cs;
    final paint = _stroke(_kBorder.withAlpha(90), 0.4);
    for (var i = 0; i <= 15; i++) {
      final t = i * cs;
      canvas.drawLine(Offset(t, 0),         Offset(t, boardSize), paint);
      canvas.drawLine(Offset(0, t),         Offset(boardSize, t), paint);
    }
  }

  // ── 7. Outer border ───────────────────────────────────────────────────────

  void _drawOuterBorder(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, boardSize, boardSize),
      _stroke(_kBorder, 1.5),
    );
  }

  // ── Star helper ───────────────────────────────────────────────────────────

  /// Draws a [points]-pointed star centred at [centre] with outer
  /// radius [outerR].  Inner radius is 45 % of the outer radius.
  void _drawStarPath(
    Canvas canvas,
    Offset centre,
    double outerR,
    int points,
    Color color,
  ) {
    final innerR = outerR * 0.45;
    final path   = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r     = i.isEven ? outerR : innerR;
      final x     = centre.dx + r * math.cos(angle);
      final y     = centre.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, _fill(color));
  }

  @override
  bool shouldRepaint(_LudoBoardPainter old) => old.boardSize != boardSize;
}
