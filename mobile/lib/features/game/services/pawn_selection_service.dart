import 'dart:async';
import 'dart:math';

// ─── PawnSelectionState ───────────────────────────────────────────────────────

/// Immutable snapshot of pawn selection state emitted by [PawnSelectionService].
class PawnSelectionState {
  const PawnSelectionState({
    required this.validPawnIndices,
    required this.selectedPawnIndex,
  });

  /// Indices of pawns that may be selected this turn (empty when no valid move).
  final List<int> validPawnIndices;

  /// Index of the pawn the active player has chosen, or null before selection.
  final int? selectedPawnIndex;

  /// True when at least one pawn can be selected.
  bool get hasValidPawns => validPawnIndices.isNotEmpty;

  /// True when [index] is in [validPawnIndices].
  bool isValid(int index) => validPawnIndices.contains(index);
}

// ─── PawnSelectionService ─────────────────────────────────────────────────────

/// Manages pawn-selection logic for a single game turn.
///
/// ## Pawn position convention
///   0        = yard (closed — not yet on board)
///   1 – 51   = main track (open — on board)
///   52 – 56  = home column
///   ≥ 57     = finished (never selectable)
///
/// ## Selection rules (standard Ludo)
///   dice == 6  → closed (pos == 0) AND open (1–56) pawns are valid.
///   dice != 6  → only open pawns (pos 1–56) are valid; closed stay disabled.
///   pos ≥ 57   → pawn is finished and is never valid.
///
/// ## Architecture
///   All selection logic lives here — no business logic inside UI widgets.
///   Widgets read [stateStream] and call [selectPawn] / [autoSelectForBot].
///
/// ## Lifecycle
///   Call [setValidPawns] after the dice roll completes.
///   Call [reset]         when the turn changes.
///   Call [dispose]       when the game session ends.
class PawnSelectionService {
  PawnSelectionService({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<int> _validPawnIndices = const [];
  int?      _selectedPawnIndex;

  final StreamController<PawnSelectionState> _controller =
      StreamController<PawnSelectionState>.broadcast();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Stream of [PawnSelectionState] updates.
  ///
  /// Emitted after every [setValidPawns], [selectPawn], [autoSelectForBot],
  /// and [reset] call.
  Stream<PawnSelectionState> get stateStream => _controller.stream;

  List<int> get validPawnIndices  => List.unmodifiable(_validPawnIndices);
  int?      get selectedPawnIndex => _selectedPawnIndex;

  // ── Static helper ───────────────────────────────────────────────────────────

  /// Pure function — compute valid pawn indices for [diceValue] and [positions].
  ///
  /// Can be called without an instance for unit testing or preview logic.
  static List<int> computeValid({
    required int        diceValue,
    required List<int>  positions,
  }) {
    final valid = <int>[];
    for (var i = 0; i < positions.length; i++) {
      final pos = positions[i];
      if (pos >= 57) continue;          // finished — never selectable
      if (diceValue == 6) {
        valid.add(i);                   // 6 unlocks everything non-finished
      } else if (pos > 0) {
        valid.add(i);                   // non-6: only open (on-track) pawns
      }
    }
    return valid;
  }

  // ── Mutation methods ────────────────────────────────────────────────────────

  /// Called after dice roll completes.
  ///
  /// Recomputes [validPawnIndices] from [diceValue] and the active player's
  /// current [positions], then clears any prior selection.
  void setValidPawns({
    required int       diceValue,
    required List<int> positions,
  }) {
    _validPawnIndices  = computeValid(diceValue: diceValue, positions: positions);
    _selectedPawnIndex = null;
    _emit();
  }

  /// Human player selects pawn [index].
  ///
  /// No-op when [index] is not in [validPawnIndices]; re-tapping another
  /// valid pawn replaces the current selection.
  void selectPawn(int index) {
    if (!_validPawnIndices.contains(index)) return;
    _selectedPawnIndex = index;
    _emit();
  }

  /// Bot automatically picks a random valid pawn.
  ///
  /// No-op when there are no valid pawns.
  void autoSelectForBot() {
    if (_validPawnIndices.isEmpty) return;
    _selectedPawnIndex =
        _validPawnIndices[_random.nextInt(_validPawnIndices.length)];
    _emit();
  }

  /// Reset for the next turn (clears both valid indices and selection).
  void reset() {
    _validPawnIndices  = const [];
    _selectedPawnIndex = null;
    _emit();
  }

  /// Release all resources. Call when the game session ends.
  void dispose() => _controller.close();

  // ── Internal ────────────────────────────────────────────────────────────────

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(PawnSelectionState(
      validPawnIndices:  List.unmodifiable(_validPawnIndices),
      selectedPawnIndex: _selectedPawnIndex,
    ));
  }
}
