import 'dart:async';

// ─── TurnState ────────────────────────────────────────────────────────────────

/// Immutable snapshot of the current turn emitted by [TurnManager].
class TurnState {
  const TurnState({
    required this.currentColor,
    required this.remainingSeconds,
    required this.isDiceEnabled,
  });

  /// Lowercase colour of the player who must now act.
  /// One of: 'red', 'blue', 'green', 'yellow'.
  final String currentColor;

  /// Seconds remaining in this turn (18 → 0).
  final int remainingSeconds;

  /// `true` only when the local (human) player is the active player.
  /// When `false`, the dice must be visually disabled and non-interactive.
  final bool isDiceEnabled;

  /// Timer progress fraction for the snake border animation:
  /// 1.0 = full (just started), 0.0 = expired.
  double get timerProgress =>
      remainingSeconds / TurnManager.turnDurationSeconds;

  @override
  String toString() =>
      'TurnState(currentColor: $currentColor, '
      'remaining: ${remainingSeconds}s, diceEnabled: $isDiceEnabled)';
}

// ─── TurnManager ──────────────────────────────────────────────────────────────

/// Manages turn order, 18-second countdown, and bot auto-advance.
///
/// ## Clockwise turn order
/// The canonical clockwise sequence is: red → blue → green → yellow.
/// [TurnManager] filters this to only the colours listed in [activeColors].
///
/// ## Supported player counts
/// - 2 players: active = ['red', 'yellow']
/// - 3 players: active = ['red', 'blue', 'yellow']
/// - 4 players: active = ['red', 'blue', 'green', 'yellow']
///
/// ## Timer behaviour
/// Each turn lasts [turnDurationSeconds] (18). A `Timer.periodic` fires
/// every second, decrements the counter, and emits a new [TurnState]. When
/// the counter reaches 0 the turn automatically advances.
///
/// ## Bot behaviour
/// If the current player's colour is in [botColors], a separate 1-second
/// `Timer` fires and advances the turn before the 18-second countdown
/// expires. The 18-second timer is cancelled when the bot timer fires.
///
/// ## What is NOT implemented here
/// - Dice rolling / random number generation
/// - Pawn movement
/// - Safe zones, cuts, home entry, or winner detection
class TurnManager {
  TurnManager({
    required List<String> activeColors,
    required String localPlayerColor,
    Set<String> botColors = const {},
    String? initialTurn,
  })  : _localPlayerColor = localPlayerColor,
        _botColors = Set.unmodifiable(botColors) {
    // Build clockwise order from the canonical sequence.
    const clockwise = ['red', 'blue', 'green', 'yellow'];
    _turnOrder = clockwise
        .where((c) => activeColors.contains(c))
        .toList(growable: false);

    assert(
      _turnOrder.isNotEmpty,
      'TurnManager: activeColors must contain at least one recognised colour.',
    );

    // Choose the starting player.
    final start =
        (initialTurn != null && _turnOrder.contains(initialTurn))
            ? initialTurn
            : _turnOrder.first;

    _currentIndex     = _turnOrder.indexOf(start);
    _remainingSeconds = turnDurationSeconds;

    _emit();
    _startCountdown();
    _scheduleBotIfNeeded();
  }

  // ── Constants ──────────────────────────────────────────────────────────────

  /// Seconds each human turn lasts before auto-advancing.
  static const int turnDurationSeconds = 18;

  /// Seconds a bot waits before auto-advancing.
  static const int botDelaySeconds = 1;

  // ── Internal state ─────────────────────────────────────────────────────────

  final String      _localPlayerColor;
  final Set<String> _botColors;

  late final List<String> _turnOrder;
  int _currentIndex     = 0;
  int _remainingSeconds = turnDurationSeconds;

  Timer? _countdownTimer;
  Timer? _botTimer;

  final StreamController<TurnState> _controller =
      StreamController<TurnState>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Stream of [TurnState] updates.
  ///
  /// New state is emitted:
  ///   - Once immediately on construction.
  ///   - Every second as the countdown ticks.
  ///   - When the turn advances (timeout or bot auto-advance).
  Stream<TurnState> get stateStream => _controller.stream;

  /// Lowercase colour of the currently active player.
  String get currentColor => _turnOrder[_currentIndex];

  /// `true` only when the local human player is active.
  bool get isDiceEnabled => currentColor == _localPlayerColor;

  /// `true` when [currentColor] belongs to a bot slot.
  bool get isCurrentBot => _botColors.contains(currentColor);

  /// Advance to the next player immediately.
  ///
  /// Call this after a player completes their action (e.g. pawn moved).
  /// Cancels any pending timers and starts fresh for the next player.
  void advanceToNextTurn() {
    _cancelTimers();
    _currentIndex     = (_currentIndex + 1) % _turnOrder.length;
    _remainingSeconds = turnDurationSeconds;
    _emit();
    _startCountdown();
    _scheduleBotIfNeeded();
  }

  /// Release all resources. Must be called when the widget is disposed.
  void dispose() {
    _cancelTimers();
    _controller.close();
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), _onCountdownTick);
  }

  void _onCountdownTick(Timer _) {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
      _emit();
    }
    if (_remainingSeconds == 0) {
      // Cancel before advancing so the new turn doesn't double-cancel.
      _cancelTimers();
      advanceToNextTurn();
    }
  }

  void _scheduleBotIfNeeded() {
    if (!isCurrentBot) return;
    _botTimer = Timer(
      const Duration(seconds: botDelaySeconds),
      () {
        if (!_controller.isClosed) advanceToNextTurn();
      },
    );
  }

  void _cancelTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(TurnState(
      currentColor:     currentColor,
      remainingSeconds: _remainingSeconds,
      isDiceEnabled:    isDiceEnabled,
    ));
  }
}
