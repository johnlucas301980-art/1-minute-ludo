import 'dart:async';

import '../../matchmaking/services/socket_client.dart';
import '../models/dice_rolled.dart';
import '../models/pawn_moved.dart';
import '../models/turn_changed.dart';

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Thrown when a gameplay operation fails at the service level (e.g. the
/// socket is not connected when the player tries to roll or move).
class GameException implements Exception {
  const GameException(this.message);
  final String message;

  @override
  String toString() => 'GameException: $message';
}

// ---------------------------------------------------------------------------
// GameService
// ---------------------------------------------------------------------------

/// Manages the in-game Socket.IO events for 1 Minute Ludo (Phase 6.3).
///
/// Responsibilities:
///  - [rollDice]        — emit `roll_dice { matchId }` to the server.
///  - [movePawn]        — emit `move_pawn { matchId, pawnIndex }` to the server.
///  - [startListening]  — register handlers for `dice_rolled`, `pawn_moved`,
///                        and `turn_changed` events.
///  - [stopListening]   — remove those handlers (call when leaving the game).
///  - [onDiceRolled]    — stream that emits a [DiceRolled] each time the
///                        server broadcasts the dice result to the room.
///  - [onPawnMoved]     — stream that emits a [PawnMoved] each time the
///                        server broadcasts a pawn movement to the room.
///  - [onTurnChanged]   — stream that emits a [TurnChanged] each time the
///                        server resolves a turn (pass or extra turn on 6).
///  - [dispose]         — stop listening and close all stream controllers.
///
/// Architecture:
///  - Requires an already-connected [SocketClient] (shared with
///    [GameLobbyService] via constructor injection from [MainShell]).
///  - Constructor DI only — no singletons, no static references.
///  - Malformed incoming payloads are silently dropped so a single bad
///    packet never crashes the stream.
///
/// Usage:
/// ```dart
/// final gameService = GameService(socketClient: socketClient);
///
/// gameService.startListening();
///
/// gameService.onDiceRolled.listen((event) {
///   // Update UI with dice value and valid moves
/// });
///
/// gameService.onPawnMoved.listen((event) {
///   // Animate pawn; handle optional capture
/// });
///
/// gameService.onTurnChanged.listen((event) {
///   // Update whose turn it is
/// });
///
/// // When the player wants to roll:
/// gameService.rollDice(matchId);
///
/// // When the player selects a pawn to move:
/// gameService.movePawn(matchId, pawnIndex);
///
/// // On game end / screen dispose:
/// gameService.dispose();
/// ```
class GameService {
  GameService({required SocketClient socketClient})
      : _socket = socketClient;

  final SocketClient _socket;

  final StreamController<DiceRolled>  _diceRolledController =
      StreamController<DiceRolled>.broadcast();

  final StreamController<PawnMoved>   _pawnMovedController =
      StreamController<PawnMoved>.broadcast();

  final StreamController<TurnChanged> _turnChangedController =
      StreamController<TurnChanged>.broadcast();

  // ── Public streams ──────────────────────────────────────────────────────────

  /// Stream that emits a [DiceRolled] event when the server broadcasts the
  /// dice result to the room.  Subscribe BEFORE calling [startListening].
  Stream<DiceRolled> get onDiceRolled => _diceRolledController.stream;

  /// Stream that emits a [PawnMoved] event when the server broadcasts a pawn
  /// movement to the room.  Subscribe BEFORE calling [startListening].
  Stream<PawnMoved> get onPawnMoved => _pawnMovedController.stream;

  /// Stream that emits a [TurnChanged] event when the server resolves the
  /// current turn.  Subscribe BEFORE calling [startListening].
  Stream<TurnChanged> get onTurnChanged => _turnChangedController.stream;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Register handlers for `dice_rolled`, `pawn_moved`, and `turn_changed`.
  ///
  /// Safe to call more than once — stale handlers are cleared before
  /// re-registering so listeners are never duplicated.
  ///
  /// Call this once after the game session starts (i.e. after `game_start` is
  /// received) and before the first dice roll.
  void startListening() {
    // Clear any stale handlers first (idempotent).
    _socket.off('dice_rolled');
    _socket.off('pawn_moved');
    _socket.off('turn_changed');

    _socket.on('dice_rolled',  _handleDiceRolled);
    _socket.on('pawn_moved',   _handlePawnMoved);
    _socket.on('turn_changed', _handleTurnChanged);
  }

  /// Unregister all gameplay event handlers from the socket.
  ///
  /// Call this when leaving the game screen before calling [dispose], or when
  /// the game ends and the session should be cleaned up.  Safe to call even
  /// when [startListening] was never called.
  void stopListening() {
    _socket.off('dice_rolled');
    _socket.off('pawn_moved');
    _socket.off('turn_changed');
  }

  /// Emit `roll_dice { matchId }` to the server.
  ///
  /// The server validates that it is the calling player's turn and that the
  /// current phase is `waiting_roll`.  The result is broadcast via
  /// `dice_rolled` to all players in the room.
  void rollDice(String matchId) {
    _socket.emit('roll_dice', {'matchId': matchId});
  }

  /// Emit `move_pawn { matchId, pawnIndex }` to the server.
  ///
  /// [pawnIndex] must be 0–3 and must appear in the [DiceRolled.validMoves]
  /// from the most recent `dice_rolled` event.  The server validates this and
  /// emits `pawn_moved` (and subsequently `turn_changed` or `game_over`) to
  /// all players in the room.
  void movePawn(String matchId, int pawnIndex) {
    _socket.emit('move_pawn', {'matchId': matchId, 'pawnIndex': pawnIndex});
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Stop listening for gameplay events and close all stream controllers.
  ///
  /// After calling [dispose], this instance must not be used again.
  void dispose() {
    stopListening();
    if (!_diceRolledController.isClosed)  _diceRolledController.close();
    if (!_pawnMovedController.isClosed)   _pawnMovedController.close();
    if (!_turnChangedController.isClosed) _turnChangedController.close();
  }

  // ── Private handlers ────────────────────────────────────────────────────────

  void _handleDiceRolled(dynamic data) {
    if (_diceRolledController.isClosed) return;
    try {
      final json = (data as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v));
      _diceRolledController.add(DiceRolled.fromJson(json));
    } catch (_) {
      // Silently drop malformed events — stream listeners must not crash.
    }
  }

  void _handlePawnMoved(dynamic data) {
    if (_pawnMovedController.isClosed) return;
    try {
      final json = (data as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v));
      _pawnMovedController.add(PawnMoved.fromJson(json));
    } catch (_) {
      // Silently drop malformed events.
    }
  }

  void _handleTurnChanged(dynamic data) {
    if (_turnChangedController.isClosed) return;
    try {
      final json = (data as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v));
      _turnChangedController.add(TurnChanged.fromJson(json));
    } catch (_) {
      // Silently drop malformed events.
    }
  }
}
