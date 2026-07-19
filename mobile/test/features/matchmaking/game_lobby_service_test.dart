import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/features/game/models/game_over.dart';
import 'package:one_minute_ludo/features/matchmaking/models/game_started.dart';
import 'package:one_minute_ludo/features/matchmaking/models/room_ready.dart';
import 'package:one_minute_ludo/features/matchmaking/services/game_lobby_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';

// ── Fake SocketClient ─────────────────────────────────────────────────────────

/// Test-only [SocketClient] subclass that never opens a real network
/// connection.  Tests can control connection state, inspect emitted events,
/// and simulate incoming socket events.
class _FakeSocketClient extends SocketClient {
  _FakeSocketClient() : super(tokenProvider: () async => 'fake-token');

  bool _connected = false;

  final List<String>                               emittedEvents = [];
  final List<dynamic>                              emittedData   = [];
  final Map<String, List<void Function(dynamic)>> _handlers     = {};

  bool disconnectCalled = false;

  @override
  bool get isConnected => _connected;

  void setConnected(bool value) => _connected = value;

  @override
  Future<void> connect() async => _connected = true;

  @override
  void disconnect() {
    _connected        = false;
    disconnectCalled  = true;
  }

  @override
  void emit(String event, [dynamic data]) {
    emittedEvents.add(event);
    emittedData.add(data);
  }

  @override
  void on(String event, void Function(dynamic) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void off(String event) {
    _handlers.remove(event);
  }

  @override
  void dispose() {
    disconnect();
    _handlers.clear();
  }

  /// Deliver a fake incoming event to all registered listeners.
  void simulateEvent(String event, dynamic data) {
    final listeners = List<void Function(dynamic)>.from(
      _handlers[event] ?? const [],
    );
    for (final listener in listeners) {
      listener(data);
    }
  }

  bool hasHandler(String event) => _handlers.containsKey(event);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const kMatchId   = 'match-uuid-1';
  const kFirstTurn = 'red';
  const kWinnerId  = 'user-winner-uuid';

  late _FakeSocketClient socket;
  late GameLobbyService  service;

  setUp(() {
    socket  = _FakeSocketClient()..setConnected(true);
    service = GameLobbyService(socketClient: socket);
  });

  tearDown(() => service.dispose());

  // ── joinRoom ───────────────────────────────────────────────────────────────

  test('joinRoom emits join_room event with matchId', () async {
    await service.joinRoom(kMatchId);
    expect(socket.emittedEvents, contains('join_room'));
    final idx  = socket.emittedEvents.indexOf('join_room');
    final data = socket.emittedData[idx] as Map;
    expect(data['matchId'], kMatchId);
  });

  test('joinRoom throws SessionExpiredException when socket not connected',
      () async {
    socket.setConnected(false);
    expect(
      () => service.joinRoom(kMatchId),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('joinRoom registers room_ready handler', () async {
    await service.joinRoom(kMatchId);
    expect(socket.hasHandler('room_ready'), isTrue);
  });

  test('joinRoom registers opponent_left handler', () async {
    await service.joinRoom(kMatchId);
    expect(socket.hasHandler('opponent_left'), isTrue);
  });

  test('joinRoom registers game_start handler', () async {
    await service.joinRoom(kMatchId);
    expect(socket.hasHandler('game_start'), isTrue);
  });

  test('joinRoom registers game_over handler', () async {
    await service.joinRoom(kMatchId);
    expect(socket.hasHandler('game_over'), isTrue);
  });

  test('joinRoom clears stale handlers before re-registering', () async {
    // First join
    await service.joinRoom(kMatchId);
    final countAfterFirst = socket._handlers['room_ready']?.length ?? 0;
    // Second join — must not stack handlers
    socket.setConnected(true);
    await service.joinRoom(kMatchId);
    final countAfterSecond = socket._handlers['room_ready']?.length ?? 0;
    expect(countAfterSecond, countAfterFirst);
  });

  // ── onRoomReady stream ─────────────────────────────────────────────────────

  test('room_ready event adds RoomReady to onRoomReady stream', () async {
    await service.joinRoom(kMatchId);

    final future = service.onRoomReady.first;
    socket.simulateEvent('room_ready', {'matchId': kMatchId});
    final event = await future;

    expect(event, isA<RoomReady>());
    expect(event.matchId, kMatchId);
  });

  test('malformed room_ready payload is silently dropped', () async {
    await service.joinRoom(kMatchId);

    var received = false;
    service.onRoomReady.listen((_) => received = true);

    // Malformed payload — missing matchId key
    socket.simulateEvent('room_ready', {'bad': 'data'});
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── onOpponentLeft stream ──────────────────────────────────────────────────

  test('opponent_left event adds matchId to onOpponentLeft stream', () async {
    await service.joinRoom(kMatchId);

    final future = service.onOpponentLeft.first;
    socket.simulateEvent('opponent_left', {'matchId': kMatchId});
    final matchId = await future;

    expect(matchId, kMatchId);
  });

  test('malformed opponent_left payload is silently dropped', () async {
    await service.joinRoom(kMatchId);

    var received = false;
    service.onOpponentLeft.listen((_) => received = true);

    socket.simulateEvent('opponent_left', 'not-a-map');
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── onGameStart stream ─────────────────────────────────────────────────────

  test('game_start event adds GameStarted to onGameStart stream', () async {
    await service.joinRoom(kMatchId);

    final future = service.onGameStart.first;
    socket.simulateEvent(
        'game_start', {'matchId': kMatchId, 'firstTurn': kFirstTurn});
    final event = await future;

    expect(event, isA<GameStarted>());
    expect(event.matchId,   kMatchId);
    expect(event.firstTurn, kFirstTurn);
  });

  test('malformed game_start payload is silently dropped', () async {
    await service.joinRoom(kMatchId);

    var received = false;
    service.onGameStart.listen((_) => received = true);

    // Malformed — missing required fields
    socket.simulateEvent('game_start', {'bad': 'data'});
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── onGameOver stream (Phase 5.6) ──────────────────────────────────────────

  test('game_over event adds GameOver to onGameOver stream', () async {
    await service.joinRoom(kMatchId);

    final future = service.onGameOver.first;
    socket.simulateEvent('game_over', {
      'matchId':  kMatchId,
      'winnerId': kWinnerId,
      'reason':   'forfeit',
    });
    final event = await future;

    expect(event, isA<GameOver>());
    expect(event.matchId,  kMatchId);
    expect(event.winnerId, kWinnerId);
    expect(event.reason,   'forfeit');
  });

  test('game_over event with reason disconnect is forwarded', () async {
    await service.joinRoom(kMatchId);

    final future = service.onGameOver.first;
    socket.simulateEvent('game_over', {
      'matchId':  kMatchId,
      'winnerId': kWinnerId,
      'reason':   'disconnect',
    });
    final event = await future;

    expect(event.reason, 'disconnect');
  });

  test('malformed game_over payload is silently dropped', () async {
    await service.joinRoom(kMatchId);

    var received = false;
    service.onGameOver.listen((_) => received = true);

    // Missing required fields
    socket.simulateEvent('game_over', {'bad': 'data'});
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── forfeit (Phase 5.6) ────────────────────────────────────────────────────

  test('forfeit emits forfeit event with matchId', () {
    service.forfeit(kMatchId);

    expect(socket.emittedEvents, contains('forfeit'));
    final idx  = socket.emittedEvents.indexOf('forfeit');
    final data = socket.emittedData[idx] as Map;
    expect(data['matchId'], kMatchId);
  });

  test('forfeit is safe to call before joinRoom', () {
    // Must not throw
    expect(() => service.forfeit(kMatchId), returnsNormally);
    expect(socket.emittedEvents, contains('forfeit'));
  });

  // ── leaveRoom ─────────────────────────────────────────────────────────────

  test('leaveRoom emits leave_room with matchId when connected', () async {
    await service.joinRoom(kMatchId);
    service.leaveRoom(kMatchId);

    expect(socket.emittedEvents, contains('leave_room'));
    final idx  = socket.emittedEvents.indexOf('leave_room');
    final data = socket.emittedData[idx] as Map;
    expect(data['matchId'], kMatchId);
  });

  test('leaveRoom removes room_ready handler', () async {
    await service.joinRoom(kMatchId);
    service.leaveRoom(kMatchId);
    expect(socket.hasHandler('room_ready'), isFalse);
  });

  test('leaveRoom removes opponent_left handler', () async {
    await service.joinRoom(kMatchId);
    service.leaveRoom(kMatchId);
    expect(socket.hasHandler('opponent_left'), isFalse);
  });

  test('leaveRoom removes game_start handler', () async {
    await service.joinRoom(kMatchId);
    service.leaveRoom(kMatchId);
    expect(socket.hasHandler('game_start'), isFalse);
  });

  test('leaveRoom removes game_over handler', () async {
    await service.joinRoom(kMatchId);
    service.leaveRoom(kMatchId);
    expect(socket.hasHandler('game_over'), isFalse);
  });

  test('leaveRoom disconnects socket', () async {
    await service.joinRoom(kMatchId);
    service.leaveRoom(kMatchId);
    expect(socket.disconnectCalled, isTrue);
  });

  test('leaveRoom is safe to call when not connected', () {
    socket.setConnected(false);
    // Must not throw
    expect(() => service.leaveRoom(kMatchId), returnsNormally);
  });

  // ── dispose ───────────────────────────────────────────────────────────────

  test('dispose closes onRoomReady stream', () async {
    service.dispose();
    expect(
      () => service.onRoomReady.listen((_) {}),
      // Listening to a closed broadcast stream is a no-op (no error).
      returnsNormally,
    );
  });

  test('dispose closes onOpponentLeft stream', () async {
    service.dispose();
    expect(
      () => service.onOpponentLeft.listen((_) {}),
      returnsNormally,
    );
  });

  test('dispose closes onGameStart stream', () async {
    service.dispose();
    expect(
      () => service.onGameStart.listen((_) {}),
      returnsNormally,
    );
  });

  test('dispose closes onGameOver stream', () async {
    service.dispose();
    expect(
      () => service.onGameOver.listen((_) {}),
      returnsNormally,
    );
  });
}
