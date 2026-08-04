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

// STEP 3
// DYNAMIC GAME BOARD
// Supports 2/3/4 Players
// Supports 1/2/3/4 Pawns
// Supports BOT Seats

// ─── LudoBoardWidget ─────────────────────────────────────────────────────────

/// Ludo board widget — Phase 6.7.3 + STEP 3 Dynamic Board.
///
/// Renders:
///  - Full board grid (15 × 15)
///  - Four coloured home yards — only [activeColors] yards are rendered at
///    full saturation; unused yards are drawn in a muted/inactive style.
///  - Each active yard shows exactly [pawnCount] placeholder circles (1–4).
///  - Coloured home paths (middle row/col of each cross arm)
///  - Centre finishing area (four coloured triangles + star)
///  - Safe-square star markers on the 8 [safeAbsolutePositions]
///  - Pawns at their current colour-relative positions
///  - Green highlight rings around valid movable pawns
///  - Gold selection ring around the currently selected pawn
///
/// Backward-compatible: [activeColors] defaults to all four colours, and
/// [pawnCount] defaults to 4, so existing callers need no changes.
class LudoBoardWidget extends StatelessWidget {
  const LudoBoardWidget({
    super.key,
    this.boardSize = 360.0,
    this.pawns,
    this.validPawnIndices,
    this.validColor,
    this.selectedPawnIndex,
    this.activeColors,
    this.pawnCount = 4,
  });

  /// Side length of the board in logical pixels.  Must be positive.
  final double boardSize;

  /// Optional pawn positions for rendering.
  ///
  /// Keys are colour names (`'red'`, `'blue'`, `'green'`, `'yellow'`).
  /// Values are lists of [pawnCount] colour-relative positions using the
  /// [ludo_path] position encoding:
  ///
  ///   - 0  ([yardPosition])                               → yard
  ///   - 1–51                                              → shared track
  ///   - 52–56 ([homeColumnStart]–[homeColumnEnd])         → home column
  ///   - 57 ([homeFinished])                               → finished
  ///
  /// When `null`, no pawns are drawn and the board renders as static layout.
  final Map<String, List<int>>? pawns;

  /// Indices of the local player's pawns that may be moved this turn.
  final List<int>? validPawnIndices;

  /// Colour of the player whose pawns are highlighted by [validPawnIndices].
  final String? validColor;

  /// Index of the pawn the local player has selected to move.
  final int? selectedPawnIndex;

  // ── STEP 3: Dynamic board parameters ──────────────────────────────────────

  /// Which of the four yard corners are active for this match.
  ///
  /// Pass a subset of `['red', 'blue', 'green', 'yellow']` to activate only
  /// the relevant yards (e.g. `['red', 'green']` for a 2-player match).
  /// Inactive yards are rendered in a muted grey style.
  ///
  /// Defaults to all four colours when `null`.
  final List<String>? activeColors;

  /// Number of pawns each player has (1–4).
  ///
  /// Controls how many placeholder circles are shown in each yard and which
  /// yard-spot positions are used.  Defaults to 4 (standard Ludo).
  final int pawnCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: CustomPaint(
        size: Size(boardSize, boardSize),
        painter: _LudoBoardPainter(
          boardSize:         boardSize,
          pawns:             pawns,
          validPawnIndices:  validPawnIndices,
          validColor:        validColor,
          selectedPawnIndex: selectedPawnIndex,
          activeColors:      activeColors,
          pawnCount:         pawnCount,
        ),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter({
    required this.boardSize,
    this.pawns,
    this.validPawnIndices,
    this.validColor,
    this.selectedPawnIndex,
    this.activeColors,
    this.pawnCount = 4,
  });

  final double boardSize;

  /// Pawn positions — same contract as [LudoBoardWidget.pawns].
  final Map<String, List<int>>? pawns;

  /// Valid pawn indices — same contract as [LudoBoardWidget.validPawnIndices].
  final List<int>? validPawnIndices;

  /// Colour of the player whose valid pawns are highlighted.
  final String? validColor;

  /// Selected pawn index — same contract as [LudoBoardWidget.selectedPawnIndex].
  final int? selectedPawnIndex;

  // STEP 3: Dynamic board fields
  /// Active yard colours — same contract as [LudoBoardWidget.activeColors].
  final List<String>? activeColors;

  /// Pawn count per player — same contract as [LudoBoardWidget.pawnCount].
  final int pawnCount;

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
    _drawHighlights(canvas); // Phase 6.7.3 — valid/selected pawn rings
    _drawPawns(canvas);      // Phase 6.4C — rendered above grid lines
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
    // STEP 3: Only fully render active yards; inactive yards are muted.
    final active = activeColors ?? ['red', 'blue', 'green', 'yellow'];
    _drawOneYard(canvas, startRow: 0, startCol: 0, color: _kRedFill,    isActive: active.contains('red'));
    _drawOneYard(canvas, startRow: 0, startCol: 9, color: _kBlueFill,   isActive: active.contains('blue'));
    _drawOneYard(canvas, startRow: 9, startCol: 9, color: _kGreenFill,  isActive: active.contains('green'));
    _drawOneYard(canvas, startRow: 9, startCol: 0, color: _kYellowFill, isActive: active.contains('yellow'));
  }

  void _drawOneYard(
    Canvas canvas, {
    required int startRow,
    required int startCol,
    required Color color,
    required bool isActive,
  }) {
    final cs = _cs;

    // STEP 3: Inactive yards use a muted grey fill.
    final displayColor = isActive ? color : const Color(0xFF757575);

    // Outer 6 × 6 coloured rectangle.
    canvas.drawRect(
      Rect.fromLTWH(startCol * cs, startRow * cs, 6 * cs, 6 * cs),
      _fill(isActive ? color : const Color(0xFF424242)),
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
      _fill(isActive ? _kWhite : const Color(0xFF2A2A2A)),
    );

    // STEP 3: Draw exactly [pawnCount] placeholder circles at dynamic spots.
    final double r = cs * 0.42;
    final spots = _yardSpotPositions(pawnCount, startRow, startCol, cs);
    for (final spot in spots) {
      canvas.drawCircle(spot, r, _fill(displayColor.withAlpha(isActive ? 180 : 80)));
      canvas.drawCircle(spot, r, _stroke(displayColor.withAlpha(isActive ? 220 : 100), 1.2));
    }

    // STEP 3: Overlay a semi-transparent dim on inactive yards.
    if (!isActive) {
      canvas.drawRect(
        Rect.fromLTWH(startCol * cs, startRow * cs, 6 * cs, 6 * cs),
        _fill(const Color(0xFF000000).withAlpha(80)),
      );
    }
  }

  // STEP 3: Dynamic yard-spot positions based on pawn count.
  //
  // Returns the pixel centres of the [pawnCount] placeholder circles inside a
  // yard whose top-left corner is at grid cell (startRow, startCol).
  //
  //   1 pawn  → single centred spot
  //   2 pawns → left / right pair
  //   3 pawns → triangle (top-centre, bottom-left, bottom-right)
  //   4 pawns → 2×2 quadrant grid (original layout)
  static List<Offset> _yardSpotPositions(
    int pawnCount,
    int startRow,
    int startCol,
    double cs,
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
          Offset((startCol + 2.5) * cs, (startRow + 1.5) * cs), // top-centre
          Offset((startCol + 1.5) * cs, (startRow + 3.5) * cs), // bottom-left
          Offset((startCol + 3.5) * cs, (startRow + 3.5) * cs), // bottom-right
        ];
      default: // 4 — original layout
        return [
          Offset((startCol + 1.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 1.5) * cs, (startRow + 3.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 3.5) * cs),
        ];
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

  // ── 8. Pawns ──────────────────────────────────────────────────────────────

  // Yard top-left cell for each colour — mirrors _drawYards call order.
  static const Map<String, (int, int)> _kYardStart = {
    'red':    (0, 0),
    'blue':   (0, 9),
    'green':  (9, 9),
    'yellow': (9, 0),
  };

  /// Solid fill colour for a pawn of [colour].
  static Color _pawnColor(String colour) => switch (colour) {
    'red'    => _kRedFill,
    'blue'   => _kBlueFill,
    'green'  => _kGreenFill,
    'yellow' => _kYellowFill,
    _        => const Color(0xFF9E9E9E),
  };

  /// Pixel centre of yard spot [pawnIndex] for [colour].
  ///
  /// STEP 3: Uses [_yardSpotPositions] so the result correctly reflects the
  /// configured [pawnCount] (1–4) rather than always assuming 4 spots.
  Offset _yardSpotCenter(String colour, int pawnIndex) {
    final (sr, sc) = _kYardStart[colour] ?? (0, 0);
    final spots = _yardSpotPositions(pawnCount, sr, sc, _cs);
    // Clamp to last spot if index is out of range (safety guard).
    final idx = pawnIndex.clamp(0, spots.length - 1);
    return spots[idx];
  }

  /// Pixel centre of the finishing triangle for [colour].
  ///
  /// Each colour's finished pawns are drawn at the centroid of their
  /// coloured triangle in the 3 × 3 centre area:
  ///   Red    → left triangle  centroid (col ≈ 6.5, row ≈ 7.5)
  ///   Blue   → top triangle   centroid (col ≈ 7.5, row ≈ 6.5)
  ///   Green  → right triangle centroid (col ≈ 8.5, row ≈ 7.5)
  ///   Yellow → bottom triangle centroid (col ≈ 7.5, row ≈ 8.5)
  Offset _finishedCenter(String colour) {
    final cs = _cs;
    return switch (colour) {
      'red'    => Offset(6.5 * cs, 7.5 * cs),
      'blue'   => Offset(7.5 * cs, 6.5 * cs),
      'green'  => Offset(8.5 * cs, 7.5 * cs),
      'yellow' => Offset(7.5 * cs, 8.5 * cs),
      _        => Offset(7.5 * cs, 7.5 * cs),
    };
  }

  /// Sub-cell offset for pawn [idx] when [total] pawns share the same cell.
  ///
  /// Distributes pawns within a cell so they do not completely obscure each
  /// other:
  ///   - 1 pawn  → centred (no offset)
  ///   - 2 pawns → left / right
  ///   - 3 pawns → triangle (top, bottom-left, bottom-right)
  ///   - 4 pawns → 2 × 2 quadrant grid
  static Offset _stackOffset(int idx, int total, double step) {
    if (total == 1) return Offset.zero;
    if (total == 2) {
      return Offset(idx == 0 ? -step : step, 0);
    }
    if (total == 3) {
      // Top / bottom-left / bottom-right arrangement.
      const baseAngle = -math.pi / 2; // start at top
      final angle = baseAngle + idx * (2 * math.pi / 3);
      return Offset(
        step * math.cos(angle),
        step * math.sin(angle),
      );
    }
    // 4 pawns: 2 × 2 quadrant layout.
    final dx = idx % 2 == 0 ? -step : step;
    final dy = idx < 2      ? -step : step;
    return Offset(dx, dy);
  }

  /// Draw a single pawn circle centred at [center] with outer radius [r].
  void _drawPawnCircle(Canvas canvas, Offset center, double r, Color color) {
    canvas.drawCircle(center, r, _fill(color));
    canvas.drawCircle(center, r, _stroke(_kWhite.withAlpha(230), 1.2));
  }

  /// Render all pawns from [pawns] on top of the board.
  ///
  /// Steps:
  ///  1. Draw yard pawns — each pawn index has its own fixed yard spot, so
  ///     there is never any overlap within the yard.
  ///  2. Collect non-yard, non-finished pawns; group by (row, col) and draw
  ///     with stacking offsets so multiple pawns on the same cell remain visible.
  ///  3. Draw finished pawns at their colour's triangle centroid with stacking.
  void _drawPawns(Canvas canvas) {
    final p = pawns;
    if (p == null) return;

    final cs    = _cs;
    final pawnR = cs * 0.30; // radius for track / home column pawns
    final yardR = cs * 0.38; // radius for yard pawns (matches placeholder size)

    // ── Step 1: Yard pawns ──────────────────────────────────────────────────
    p.forEach((colour, positions) {
      final fill = _pawnColor(colour);
      final len  = positions.length.clamp(0, 4);
      for (var i = 0; i < len; i++) {
        if (positions[i] == yardPosition) {
          final center = _yardSpotCenter(colour, i);
          _drawPawnCircle(canvas, center, yardR, fill);
        }
      }
    });

    // ── Step 2: Track / home-column pawns — group by (row, col) ────────────
    final Map<(int, int), List<(String, int)>> trackGroups = {};

    // ── Step 3 prep: finished pawn counts per colour ────────────────────────
    final Map<String, int> finishedCount = {};

    p.forEach((colour, positions) {
      final homeCells = kHomeCells[colour];
      final len = positions.length.clamp(0, 4);
      for (var i = 0; i < len; i++) {
        final relPos = positions[i];
        if (relPos == yardPosition) continue;

        if (relPos == homeFinished) {
          finishedCount[colour] = (finishedCount[colour] ?? 0) + 1;
          continue;
        }

        final (int, int) rc;
        if (relPos >= homeColumnStart && relPos <= homeColumnEnd) {
          // Home column: index into kHomeCells.
          final homeIdx = relPos - homeColumnStart;
          rc = homeCells![homeIdx];
        } else {
          // Shared track (relPos 1–51).
          final absPos = relativeToAbsolute(relPos, colour);
          rc = kTrackCells[absPos];
        }

        trackGroups.putIfAbsent(rc, () => []).add((colour, i));
      }
    });

    // Draw track / home groups.
    trackGroups.forEach((rc, group) {
      final (row, col) = rc;
      final nominalCenter = Offset((col + 0.5) * cs, (row + 0.5) * cs);
      final n = group.length;
      for (var k = 0; k < n; k++) {
        final (colour, _) = group[k];
        final fill   = _pawnColor(colour);
        final offset = _stackOffset(k, n, pawnR * 0.55);
        _drawPawnCircle(canvas, nominalCenter + offset, pawnR, fill);
      }
    });

    // Draw finished pawns.
    finishedCount.forEach((colour, count) {
      final fill    = _pawnColor(colour);
      final nominal = _finishedCenter(colour);
      final r       = pawnR * 0.80; // slightly smaller to fit the triangle
      for (var k = 0; k < count; k++) {
        final offset = _stackOffset(k, count, r * 0.55);
        _drawPawnCircle(canvas, nominal + offset, r, fill);
      }
    });
  }

  // ── 9. Highlight rings (Phase 6.7.3) ─────────────────────────────────────

  /// Returns the pixel centre of a pawn for highlight/selection drawing.
  ///
  /// The returned offset is always the *nominal* cell centre (no stacking
  /// sub-offset), which is correct for rings that surround the whole group.
  /// For yard pawns the per-spot centre is used so the ring sits on the pawn.
  Offset? _pawnCenterForHighlight(String colour, int pawnIndex, int relPos) {
    final cs = _cs;
    if (relPos == yardPosition) {
      return _yardSpotCenter(colour, pawnIndex);
    }
    if (relPos == homeFinished) {
      return _finishedCenter(colour);
    }
    if (relPos >= homeColumnStart && relPos <= homeColumnEnd) {
      final cells = kHomeCells[colour];
      if (cells == null) return null;
      final homeIdx = relPos - homeColumnStart;
      if (homeIdx < 0 || homeIdx >= cells.length) return null;
      final (row, col) = cells[homeIdx];
      return Offset((col + 0.5) * cs, (row + 0.5) * cs);
    }
    // Shared track (relPos 1–51).
    final absPos = relativeToAbsolute(relPos, colour);
    final (row, col) = kTrackCells[absPos];
    return Offset((col + 0.5) * cs, (row + 0.5) * cs);
  }

  /// Draws highlight rings for valid movable pawns and the selected pawn.
  ///
  /// Valid pawns get a green ring; the selected pawn gets a gold ring.
  /// Rings are drawn between the grid and pawn layers so they appear as a
  /// visible glow without obscuring the pawn circle itself.
  void _drawHighlights(Canvas canvas) {
    final p  = pawns;
    final vi = validPawnIndices;
    final vc = validColor;
    final si = selectedPawnIndex;
    if (p == null) return;
    if ((vi == null || vi.isEmpty || vc == null) && si == null) return;

    final cs        = _cs;
    final positions = vc != null ? p[vc] : null;

    // ── Green rings around valid movable pawns ──────────────────────────────
    if (vi != null && vi.isNotEmpty && positions != null && vc != null) {
      final ringPaint = Paint()
        ..color      = const Color(0xFF4CAF50)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = cs * 0.13;

      for (final idx in vi) {
        if (idx < 0 || idx >= positions.length) continue;
        final relPos = positions[idx];
        final center = _pawnCenterForHighlight(vc, idx, relPos);
        if (center == null) continue;
        final baseR = relPos == yardPosition ? cs * 0.38 : cs * 0.30;
        canvas.drawCircle(center, baseR + cs * 0.10, ringPaint);
      }
    }

    // ── Gold ring around the selected pawn ──────────────────────────────────
    if (si != null && vc != null && positions != null && si < positions.length) {
      final selectedPaint = Paint()
        ..color      = const Color(0xFFFFD700)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = cs * 0.15;
      final relPos = positions[si];
      final center = _pawnCenterForHighlight(vc, si, relPos);
      if (center != null) {
        final baseR = relPos == yardPosition ? cs * 0.38 : cs * 0.30;
        canvas.drawCircle(center, baseR + cs * 0.13, selectedPaint);
      }
    }
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
  bool shouldRepaint(_LudoBoardPainter old) =>
      old.boardSize         != boardSize         ||
      old.pawns             != pawns             ||
      old.validPawnIndices  != validPawnIndices  ||
      old.validColor        != validColor        ||
      old.selectedPawnIndex != selectedPawnIndex ||
      old.activeColors      != activeColors      ||
      old.pawnCount         != pawnCount;
}
