import 'dart:async';

// ─── PawnMovementService ──────────────────────────────────────────────────────

/// Animates a single pawn along the Ludo track one tile at a time.
///
/// ## Position convention (mirrors [PawnSelectionService])
///   0        = yard (closed)
///   1 – 51   = main track (open)
///   52 – 56  = home column
///   ≥ 57     = finished (never passed to this service)
///
/// ## Movement rules (Step 8 — no safe-cell, cut, or winner logic)
///   Yard pawn (pos == 0): moves to position 1 (one step; dice must be 6).
///   Track pawn (pos  > 0): advances by [diceValue] steps, one per tick.
///   Position is capped at 56; no wrap-around.
///
/// ## Usage
///   1. Call [startMovement] after a pawn is selected.
///   2. Supply [onStep] — fires each tile with the new position; use it to
///      call setState and update _pawnPositions in the screen.
///   3. Supply [onComplete] — fires once after the final tile; use it to
///      clear [PawnSelectionService] and reset [DiceService].
///   4. Call [dispose] when the game session ends.
class PawnMovementService {
  static const int stepMs = 175; // ms per tile — keeps animation smooth

  Timer? _timer;
  bool   _isMoving = false;

  /// True while an animation is in progress.
  bool get isMoving => _isMoving;

  // ── Static helper ───────────────────────────────────────────────────────────

  /// Compute the ordered list of intermediate positions for one move.
  ///
  /// Pure — can be called without an instance for unit testing.
  static List<int> buildPath(int startPos, int diceValue) {
    final path = <int>[];

    if (startPos == 0) {
      // Yard → entry: one step to position 1 regardless of dice value.
      path.add(1);
    } else {
      var pos = startPos;
      for (var i = 0; i < diceValue; i++) {
        pos = (pos + 1).clamp(1, 56);
        path.add(pos);
        if (pos >= 56) break; // already at home-column end
      }
    }

    return path;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Begin animating the pawn from [startPosition] by [diceValue] tiles.
  ///
  /// No-op if already moving.
  void startMovement({
    required int                  startPosition,
    required int                  diceValue,
    required void Function(int)   onStep,
    required void Function()      onComplete,
  }) {
    if (_isMoving) return;
    _isMoving = true;
    final path = buildPath(startPosition, diceValue);
    _step(path, 0, onStep, onComplete);
  }

  /// Cancel any in-progress movement without firing [onComplete].
  void cancel() {
    _timer?.cancel();
    _timer    = null;
    _isMoving = false;
  }

  /// Release resources. Call when the game session ends.
  void dispose() => cancel();

  // ── Internal ────────────────────────────────────────────────────────────────

  void _step(
    List<int>            path,
    int                  idx,
    void Function(int)   onStep,
    void Function()      onComplete,
  ) {
    if (idx >= path.length) {
      _isMoving = false;
      _timer    = null;
      onComplete();
      return;
    }

    onStep(path[idx]);

    _timer = Timer(
      const Duration(milliseconds: stepMs),
      () => _step(path, idx + 1, onStep, onComplete),
    );
  }
}
