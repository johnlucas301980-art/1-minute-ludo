import 'dart:async';
import 'dart:math';

// ─── DiceState ────────────────────────────────────────────────────────────────

/// Immutable snapshot of dice state emitted by [DiceService].
class DiceState {
  const DiceState({
    required this.value,
    required this.isRolling,
    required this.hasRolled,
  });

  /// Rolled value (1–6), or null before rolling completes.
  final int? value;

  /// True during the ~1-second rolling animation.
  final bool isRolling;

  /// True once the roll animation has finished and [value] is set.
  final bool hasRolled;

  /// True when a roll may be initiated (not rolling, not already rolled).
  bool get canRoll => !isRolling && !hasRolled;
}

// ─── DiceService ──────────────────────────────────────────────────────────────

/// Manages all dice logic for a single game session.
///
/// ## Responsibilities
/// - Trigger a ~1-second rolling animation on [roll] or [scheduleBotRoll].
/// - Generate a random value (1–6) after the animation completes.
/// - Store [currentDiceValue] — the single source of truth for the rolled number.
/// - Prevent double-rolling: [canRoll] becomes `false` the moment rolling starts
///   and stays `false` until [reset] is called.
/// - Expose [stateStream] so widgets can rebuild reactively.
///
/// ## What this service does NOT do
/// - Pawn selection, pawn movement, safe zones, or winner detection.
/// - Turn management — that is [TurnManager]'s responsibility.
///
/// ## Lifecycle
/// Call [reset] when the active turn changes and [dispose] when the game ends.
class DiceService {
  DiceService({Random? random}) : _random = random ?? Random();

  static const int rollDurationMs = 1000;
  static const int botDelayMs     = 1000;

  final Random _random;

  Timer? _rollTimer;
  Timer? _botTimer;

  int?  _value;
  bool  _isRolling = false;
  bool  _hasRolled = false;

  final StreamController<DiceState> _controller =
      StreamController<DiceState>.broadcast();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Stream of [DiceState] updates.
  ///
  /// A new state is emitted:
  ///   - When rolling starts ([isRolling] = true).
  ///   - When rolling ends ([hasRolled] = true, [value] set).
  ///   - When [reset] is called.
  Stream<DiceState> get stateStream => _controller.stream;

  /// The most recently rolled value (1–6), or null before rolling completes.
  int? get currentDiceValue => _value;

  /// True during the rolling animation.
  bool get isRolling => _isRolling;

  /// True once rolling has completed and [currentDiceValue] is set.
  bool get hasRolled => _hasRolled;

  /// True when a roll may be initiated.
  bool get canRoll => !_isRolling && !_hasRolled;

  /// Initiate a human-triggered roll.
  ///
  /// No-op if [canRoll] is false (already rolling or already rolled this turn).
  void roll() {
    if (!canRoll) return;
    _beginRoll();
  }

  /// Schedule an automatic bot roll after [delayMs] milliseconds.
  ///
  /// Cancels any previously scheduled bot timer before setting the new one.
  void scheduleBotRoll({int delayMs = botDelayMs}) {
    _botTimer?.cancel();
    _botTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_controller.isClosed) _beginRoll();
    });
  }

  /// Reset dice state for the next turn.
  ///
  /// Call this whenever the active player changes.
  void reset() {
    _rollTimer?.cancel();
    _botTimer?.cancel();
    _rollTimer = null;
    _botTimer  = null;
    _value     = null;
    _isRolling = false;
    _hasRolled = false;
    _emit();
  }

  /// Release all resources. Call when the game session ends.
  void dispose() {
    _rollTimer?.cancel();
    _botTimer?.cancel();
    _controller.close();
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  void _beginRoll() {
    if (_isRolling || _hasRolled) return;
    _isRolling = true;
    _emit();
    _rollTimer = Timer(
      const Duration(milliseconds: rollDurationMs),
      _onRollComplete,
    );
  }

  void _onRollComplete() {
    if (_controller.isClosed) return;
    _value     = _random.nextInt(6) + 1; // 1–6
    _isRolling = false;
    _hasRolled = true;
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(DiceState(
      value:     _value,
      isRolling: _isRolling,
      hasRolled: _hasRolled,
    ));
  }
}
