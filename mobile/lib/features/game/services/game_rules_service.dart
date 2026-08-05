import 'dart:math';

import '../models/ludo_path.dart';
import '../models/valid_move.dart';

// ─── CutResult ────────────────────────────────────────────────────────────────

/// Identifies a captured opponent pawn after a cut.
class CutResult {
  const CutResult({
    required this.capturedColor,
    required this.capturedPawnIndex,
  });

  /// Board colour of the opponent whose pawn was captured.
  final String capturedColor;

  /// Index (0–3) of the captured pawn within that colour's list.
  final int capturedPawnIndex;

  @override
  String toString() =>
      'CutResult(capturedColor: $capturedColor, '
      'capturedPawnIndex: $capturedPawnIndex)';
}

// ─── GameRulesService ─────────────────────────────────────────────────────────

/// Encapsulates the three Step-9 game rules for 1 Minute Ludo:
///
///  1. **Safe Cell**  — Pawns on designated safe squares can never be cut.
///  2. **Cut Pawn**   — Landing on a non-safe shared-track square occupied by
///                      an opponent pawn sends that pawn back to the yard (0).
///                      Own pawns are never cut.
///  3. **Extra Turn** — The active player earns another turn when:
///                        - dice == 6, OR
///                        - they cut an opponent pawn.
///                      Otherwise the turn passes to the next player via
///                      [TurnManager.advanceToNextTurn].
///
/// All methods are **pure** — no UI, no timers, no streams.
///
/// Both human and BOT gameplay use this service.  [selectBotPawn] applies the
/// same cut-preference strategy when choosing which pawn the bot moves.
///
/// Safe square data and coordinate conversion are imported from [ludo_path.dart]
/// which mirrors the authoritative constants in `backend/src/socket/game_engine.ts`.
class GameRulesService {
  GameRulesService({Random? random}) : _random = random ?? Random();

  final Random _random;

  // ── 1. Safe Cell ─────────────────────────────────────────────────────────────

  /// Returns `true` when [toPos] (colour-relative) for [movingColor] is immune
  /// to pawn captures.
  ///
  /// A square is safe when:
  ///   - It is outside the shared track (yard = 0, home column ≥ 52, or
  ///     finished ≥ 57).  These squares can never host an opponent pawn.
  ///   - It is one of the eight designated safe squares on the shared track
  ///     (the four colour entry squares and four star squares).
  ///
  /// Mirrors the server-side `isAbsoluteSafe` + yard/home-column guards in
  /// `game_engine.ts`.
  bool isSafeDestination(int toPos, String movingColor) {
    // Yard, home column, and finished positions are inherently safe.
    if (toPos <= yardPosition || toPos >= homeColumnStart) return true;
    // Shared track: convert to absolute and check the official safe-square set.
    return isAbsoluteSafe(relativeToAbsolute(toPos, movingColor));
  }

  // ── 2. Cut Pawn ──────────────────────────────────────────────────────────────

  /// Scan [pawns] for an opponent pawn that shares the same absolute square as
  /// the moving pawn's destination [toPos].
  ///
  /// Returns a [CutResult] when a cut occurs, `null` otherwise.
  ///
  /// No cut occurs when:
  ///   - [toPos] is in the yard, home column, or finished zone.
  ///   - The destination is a safe square.
  ///   - No opponent pawn is present on the shared track at that position.
  ///
  /// Own-colour pawns are never cut.
  CutResult? findCut({
    required Map<String, List<int>> pawns,
    required String movingColor,
    required int toPos,
  }) {
    // Only shared-track positions (1–51) can result in a cut.
    if (toPos < trackEntryPosition || toPos >= homeColumnStart) return null;

    // Safe squares are immune — no cut is possible.
    final absPos = relativeToAbsolute(toPos, movingColor);
    if (isAbsoluteSafe(absPos)) return null;

    // Search every opponent colour for a pawn on the same absolute square.
    for (final entry in pawns.entries) {
      final opponentColor = entry.key;
      if (opponentColor == movingColor) continue; // never cut own pawn

      final opponentPawns = entry.value;
      for (var i = 0; i < opponentPawns.length; i++) {
        final oppPos = opponentPawns[i];
        // Opponent pawn must be on the shared track to be cuttable.
        if (oppPos < trackEntryPosition || oppPos >= homeColumnStart) continue;

        final oppAbs = relativeToAbsolute(oppPos, opponentColor);
        if (oppAbs == absPos) {
          return CutResult(capturedColor: opponentColor, capturedPawnIndex: i);
        }
      }
    }
    return null;
  }

  /// Apply [cut] by resetting the captured pawn to the yard (position 0) and
  /// clearing any selection it may have held.
  ///
  /// Mutates the list inside [pawns] in-place.  Callers are responsible for
  /// triggering a UI rebuild after calling this (e.g. via `setState`).
  ///
  /// Returns the same [pawns] map so calls can be chained or used inline.
  Map<String, List<int>> applyCut({
    required Map<String, List<int>> pawns,
    required CutResult cut,
  }) {
    final list = pawns[cut.capturedColor];
    if (list != null && cut.capturedPawnIndex < list.length) {
      list[cut.capturedPawnIndex] = yardPosition; // back to yard
    }
    return pawns;
  }

  // ── 3. Extra Turn ─────────────────────────────────────────────────────────────

  /// Returns `true` when the active player earns another turn.
  ///
  /// Conditions (either is sufficient, matching `game_engine.ts`):
  ///   - [diceValue] == 6
  ///   - [didCut] is `true` (the move cut an opponent pawn)
  ///
  /// Otherwise the caller should advance to the next player via
  /// [TurnManager.advanceToNextTurn].
  bool getsExtraTurn({required int diceValue, required bool didCut}) =>
      diceValue == 6 || didCut;

  // ── BOT pawn selection ────────────────────────────────────────────────────────

  /// Choose the best pawn for the bot to move from [validMoves], applying the
  /// same rules a skilled human player would consider:
  ///
  ///  1. **Prefer cutting moves** — a cut guarantees an extra turn and weakens
  ///     the opponent.  If multiple cuts are possible, one is chosen at random.
  ///  2. **Fall back to random** — when no cutting move is available, any valid
  ///     move is chosen uniformly at random.
  ///
  /// Returns the chosen [ValidMove.pawnIndex], or `null` when [validMoves] is
  /// empty (the caller should not emit `move_pawn` in that case).
  ///
  /// [pawns] must contain the current positions of ALL colours so that
  /// [findCut] can check for opponent pawns on the destination square.
  int? selectBotPawn({
    required List<ValidMove> validMoves,
    required Map<String, List<int>> pawns,
    required String botColor,
  }) {
    if (validMoves.isEmpty) return null;

    // Prefer moves that cut an opponent pawn.
    final cuttingMoves = validMoves.where((m) {
      return findCut(
        pawns:        pawns,
        movingColor:  botColor,
        toPos:        m.toPos,
      ) != null;
    }).toList();

    if (cuttingMoves.isNotEmpty) {
      return cuttingMoves[_random.nextInt(cuttingMoves.length)].pawnIndex;
    }

    // Fall back to a random valid move.
    return validMoves[_random.nextInt(validMoves.length)].pawnIndex;
  }
}
