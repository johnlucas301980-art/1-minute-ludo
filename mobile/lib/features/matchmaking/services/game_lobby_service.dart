import 'dart:async';

import '../../../core/errors/api_exception.dart';
import '../models/game_started.dart';
import '../models/room_ready.dart';
import 'socket_client.dart';

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Thrown when a game lobby operation fails for a reason other than session
/// expiry (e.g. the player is not in the match, unexpected server error).
class GameLobbyException implements Exception {
  const GameLobbyException(this.message);
  final String message;

  @override
  String toString() => 'GameLobbyException: $message';
}

// ---------------------------------------------------------------------------
// GameLobbyService
// ---------------------------------------------------------------------------

/// Manages the pre-game lobby for 1 Minute Ludo.
///
/// After a match is found (Phase 5.3), both players must join the game room
/// via Socket.IO before gameplay can begin.  This service handles that flow.
///
/// Responsibilities:
///  - [joinRoom]       — emit `join_room` on the already-connected socket.
///  - [leaveRoom]      — emit `leave_room` and disconnect the socket.
///  - [onRoomReady]    — stream that emits one [RoomReady] event when both
///                       players have joined the room.
///  - [onOpponentLeft] — stream that emits the matchId when the opponent
///                       disconnects from the lobby.
///  - [onGameStart]    — stream that emits a [GameStarted] event when the
///                       server has updated the match to `in_progress` and
///                       determined the first turn (Phase 5.5).
///  - [dispose]        — close streams and release resources.
///
/// Architecture:
///  - Requires an already-connected [SocketClient] (the socket is connected
///    during matchmaking in Phase 5.1–5.3).
///  - If the socket is not connected when [joinRoom] is called, a
///    [SessionExpiredException] is thrown — the parent must route to login.
///  - Constructor DI only — no singletons or static references.
///
/// Usage:
/// ```dart
/// // After MatchmakingScreen receives match_found:
/// final service = GameLobbyService(socketClient: socketClient);
///
/// service.onGameStart.listen((event) {
///   // Server confirmed match in_progress — navigate to GameScreen
/// });
///
/// service.onRoomReady.listen((event) {
///   // Both players ready — waiting for game_start
/// });
///
/// await service.joinRoom(matchFound.matchId);
///
/// // …later, if player leaves:
/// service.leaveRoom(matchFound.matchId);
/// service.dispose();
/// ```
class GameLobbyService {
  GameLobbyService({required SocketClient socketClient})
      : _socket = socketClient;

  final SocketClient _socket;

  final StreamController<RoomReady>   _roomReadyController =
      StreamController<RoomReady>.broadcast();

  final StreamController<String>      _opponentLeftController =
      StreamController<String>.broadcast();

  final StreamController<GameStarted> _gameStartedController =
      StreamController<GameStarted>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Stream that emits a [RoomReady] event when both players have joined the
  /// game room.  Subscribe BEFORE calling [joinRoom].
  Stream<RoomReady> get onRoomReady => _roomReadyController.stream;

  /// Stream that emits the matchId when the opponent disconnects from the
  /// game lobby before the room is ready.
  Stream<String> get onOpponentLeft => _opponentLeftController.stream;

  /// Stream that emits a [GameStarted] event when the server has set the
  /// match to `in_progress` and emits `game_start` (~2.5 s after
  /// `room_ready`).  Subscribe BEFORE calling [joinRoom].
  Stream<GameStarted> get onGameStart => _gameStartedController.stream;

  // ── Socket.IO ──────────────────────────────────────────────────────────────

  /// Emit `join_room` to the server for the given [matchId].
  ///
  /// Requires the [SocketClient] to already be connected — the socket is
  /// established during matchmaking and remains open until explicitly
  /// disconnected.
  ///
  /// Registers handlers for `room_ready`, `opponent_left`, and `game_start`
  /// events before emitting.  Calling [joinRoom] a second time is safe —
  /// stale handlers are cleared first.
  ///
  /// Throws:
  ///  - [SessionExpiredException] if the socket is not connected (session
  ///    expired or socket was prematurely closed).
  ///  - [GameLobbyException] for any other unexpected failure.
  Future<void> joinRoom(String matchId) async {
    if (!_socket.isConnected) {
      throw SessionExpiredException();
    }

    // Clear stale handlers before re-registering (safe on repeated calls)
    _socket.off('room_ready');
    _socket.off('opponent_left');
    _socket.off('game_start');
    _socket.on('room_ready',   _handleRoomReady);
    _socket.on('opponent_left', _handleOpponentLeft);
    _socket.on('game_start',   _handleGameStart);

    _socket.emit('join_room', {'matchId': matchId});
  }

  /// Emit `leave_room`, clean up event handlers, and disconnect the socket.
  ///
  /// Safe to call even when not in the room.  After this call the socket is
  /// disconnected; a new [MatchmakingService.joinQueue] call will reconnect.
  void leaveRoom(String matchId) {
    if (_socket.isConnected) {
      _socket.emit('leave_room', {'matchId': matchId});
    }
    _socket.off('room_ready');
    _socket.off('opponent_left');
    _socket.off('game_start');
    _socket.disconnect();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Release all resources: close the stream controllers.
  ///
  /// After calling [dispose], this instance must not be used again.
  void dispose() {
    _socket.off('room_ready');
    _socket.off('opponent_left');
    _socket.off('game_start');
    if (!_roomReadyController.isClosed)   _roomReadyController.close();
    if (!_opponentLeftController.isClosed) _opponentLeftController.close();
    if (!_gameStartedController.isClosed)  _gameStartedController.close();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _handleRoomReady(dynamic data) {
    if (_roomReadyController.isClosed) return;
    try {
      final json = (data as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v));
      _roomReadyController.add(RoomReady.fromJson(json));
    } catch (_) {
      // Silently drop malformed events — the stream listener must not crash.
    }
  }

  void _handleOpponentLeft(dynamic data) {
    if (_opponentLeftController.isClosed) return;
    try {
      final json = (data as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v));
      final matchId = json['matchId'] as String? ?? '';
      _opponentLeftController.add(matchId);
    } catch (_) {
      // Silently drop malformed events.
    }
  }

  void _handleGameStart(dynamic data) {
    if (_gameStartedController.isClosed) return;
    try {
      final json = (data as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v));
      _gameStartedController.add(GameStarted.fromJson(json));
    } catch (_) {
      // Silently drop malformed events.
    }
  }
}
