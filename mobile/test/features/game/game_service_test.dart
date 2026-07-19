import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/dice_rolled.dart';
import 'package:one_minute_ludo/features/game/models/pawn_moved.dart';
import 'package:one_minute_ludo/features/game/models/turn_changed.dart';
import 'package:one_minute_ludo/features/game/services/game_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';

// ── Fake SocketClient ─────────────────────────────────────────────────────────

/// Test-only [SocketClient] that never opens a real network connection.
/// Tests can inspect emitted events and simulate incoming socket events.
class _FakeSocketClient extends SocketClient {
  _FakeSocketClient() : super(tokenProvider: () async => 'fake-token');

  final List<String>                               emittedEvents = [];
  final List<dynamic>                              emittedData   = [];
  final Map<String, List<void Function(dynamic)>> _handlers     = {};

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

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
  void dispose() {}

  /// Deliver a fake incoming event to all registered listeners.
  void simulateEvent(String event, dynamic data) {
    final listeners = List<void Function(dynamic)>.from(
      _handlers[event] ?? const [],
    );
    for (final fn in listeners) {
      fn(data);
    }
  }

  bool hasHandler(String event) => _handlers.containsKey(event);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const kMatchId = 'match-uuid-1';

  late _FakeSocketClient socket;
  late GameService       service;

  setUp(() {
    socket  = _FakeSocketClient();
    service = GameService(socketClient: socket);
  });

  tearDown(() => service.dispose());

  // ── rollDice ───────────────────────────────────────────────────────────────

  test('1 — rollDice emits roll_dice with matchId', () {
    service.rollDice(kMatchId);
    expect(socket.emittedEvents, contains('roll_dice'));
    final idx  = socket.emittedEvents.indexOf('roll_dice');
    final data = socket.emittedData[idx] as Map;
    expect(data['matchId'], kMatchId);
  });

  test('2 — rollDice can be called multiple times (one event per call)', () {
    service.rollDice(kMatchId);
    service.rollDice(kMatchId);
    expect(socket.emittedEvents.where((e) => e == 'roll_dice'), hasLength(2));
  });

  // ── movePawn ───────────────────────────────────────────────────────────────

  test('3 — movePawn emits move_pawn with matchId and pawnIndex', () {
    service.movePawn(kMatchId, 2);
    expect(socket.emittedEvents, contains('move_pawn'));
    final idx  = socket.emittedEvents.indexOf('move_pawn');
    final data = socket.emittedData[idx] as Map;
    expect(data['matchId'],   kMatchId);
    expect(data['pawnIndex'], 2);
  });

  test('4 — movePawn sends the correct pawnIndex (0–3)', () {
    for (var i = 0; i < 4; i++) {
      service.movePawn(kMatchId, i);
    }
    final indices = socket.emittedEvents
        .asMap()
        .entries
        .where((e) => e.value == 'move_pawn')
        .map((e) => (socket.emittedData[e.key] as Map)['pawnIndex'] as int)
        .toList();
    expect(indices, [0, 1, 2, 3]);
  });

  // ── startListening ─────────────────────────────────────────────────────────

  test('5 — startListening registers dice_rolled handler', () {
    service.startListening();
    expect(socket.hasHandler('dice_rolled'), isTrue);
  });

  test('6 — startListening registers pawn_moved handler', () {
    service.startListening();
    expect(socket.hasHandler('pawn_moved'), isTrue);
  });

  test('7 — startListening registers turn_changed handler', () {
    service.startListening();
    expect(socket.hasHandler('turn_changed'), isTrue);
  });

  test('8 — startListening clears stale handlers before re-registering', () {
    service.startListening();
    final countAfterFirst = socket._handlers['dice_rolled']?.length ?? 0;
    service.startListening();
    final countAfterSecond = socket._handlers['dice_rolled']?.length ?? 0;
    expect(countAfterSecond, countAfterFirst);
  });

  // ── stopListening ──────────────────────────────────────────────────────────

  test('9 — stopListening removes dice_rolled handler', () {
    service.startListening();
    service.stopListening();
    expect(socket.hasHandler('dice_rolled'), isFalse);
  });

  test('10 — stopListening removes pawn_moved handler', () {
    service.startListening();
    service.stopListening();
    expect(socket.hasHandler('pawn_moved'), isFalse);
  });

  test('11 — stopListening removes turn_changed handler', () {
    service.startListening();
    service.stopListening();
    expect(socket.hasHandler('turn_changed'), isFalse);
  });

  test('12 — stopListening is safe before startListening is called', () {
    expect(() => service.stopListening(), returnsNormally);
  });

  // ── onDiceRolled stream ────────────────────────────────────────────────────

  test('13 — dice_rolled event delivers DiceRolled to onDiceRolled stream', () async {
    service.startListening();

    final future = service.onDiceRolled.first;
    socket.simulateEvent('dice_rolled', {
      'matchId':    kMatchId,
      'color':      'red',
      'value':      6,
      'validMoves': <dynamic>[
        {'pawnIndex': 0, 'fromPos': 0, 'toPos': 1},
      ],
    });
    final event = await future;

    expect(event, isA<DiceRolled>());
    expect(event.matchId,          kMatchId);
    expect(event.color,            'red');
    expect(event.value,            6);
    expect(event.validMoves,       hasLength(1));
    expect(event.validMoves[0].pawnIndex, 0);
  });

  test('14 — dice_rolled with empty validMoves is delivered correctly', () async {
    service.startListening();

    final future = service.onDiceRolled.first;
    socket.simulateEvent('dice_rolled', {
      'matchId':    kMatchId,
      'color':      'blue',
      'value':      3,
      'validMoves': <dynamic>[],
    });
    final event = await future;

    expect(event.validMoves, isEmpty);
  });

  test('15 — malformed dice_rolled payload is silently dropped', () async {
    service.startListening();

    var received = false;
    service.onDiceRolled.listen((_) => received = true);

    socket.simulateEvent('dice_rolled', {'bad': 'data'});
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── onPawnMoved stream ─────────────────────────────────────────────────────

  test('16 — pawn_moved event delivers PawnMoved to onPawnMoved stream', () async {
    service.startListening();

    final future = service.onPawnMoved.first;
    socket.simulateEvent('pawn_moved', {
      'matchId':    kMatchId,
      'color':      'blue',
      'pawnIndex':  1,
      'toPosition': 20,
    });
    final event = await future;

    expect(event, isA<PawnMoved>());
    expect(event.matchId,    kMatchId);
    expect(event.color,      'blue');
    expect(event.pawnIndex,  1);
    expect(event.toPosition, 20);
  });

  test('17 — pawn_moved with capture fields is delivered correctly', () async {
    service.startListening();

    final future = service.onPawnMoved.first;
    socket.simulateEvent('pawn_moved', {
      'matchId':           kMatchId,
      'color':             'green',
      'pawnIndex':         2,
      'toPosition':        35,
      'capturedColor':     'yellow',
      'capturedPawnIndex': 3,
    });
    final event = await future;

    expect(event.capturedColor,     'yellow');
    expect(event.capturedPawnIndex, 3);
  });

  test('18 — pawn_moved without capture fields has null capture properties',
      () async {
    service.startListening();

    final future = service.onPawnMoved.first;
    socket.simulateEvent('pawn_moved', {
      'matchId':    kMatchId,
      'color':      'red',
      'pawnIndex':  0,
      'toPosition': 10,
    });
    final event = await future;

    expect(event.capturedColor,     isNull);
    expect(event.capturedPawnIndex, isNull);
  });

  test('19 — malformed pawn_moved payload is silently dropped', () async {
    service.startListening();

    var received = false;
    service.onPawnMoved.listen((_) => received = true);

    socket.simulateEvent('pawn_moved', 'not-a-map');
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── onTurnChanged stream ───────────────────────────────────────────────────

  test('20 — turn_changed event delivers TurnChanged to onTurnChanged stream',
      () async {
    service.startListening();

    final future = service.onTurnChanged.first;
    socket.simulateEvent('turn_changed', {
      'matchId':  kMatchId,
      'nextTurn': 'yellow',
    });
    final event = await future;

    expect(event, isA<TurnChanged>());
    expect(event.matchId,  kMatchId);
    expect(event.nextTurn, 'yellow');
  });

  test('21 — extra-turn scenario: turn_changed carries same colour as mover',
      () async {
    service.startListening();

    final future = service.onTurnChanged.first;
    socket.simulateEvent('turn_changed', {
      'matchId':  kMatchId,
      'nextTurn': 'red', // same as the player who rolled 6
    });
    final event = await future;

    expect(event.nextTurn, 'red');
  });

  test('22 — malformed turn_changed payload is silently dropped', () async {
    service.startListening();

    var received = false;
    service.onTurnChanged.listen((_) => received = true);

    socket.simulateEvent('turn_changed', null);
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── dispose ────────────────────────────────────────────────────────────────

  test('23 — dispose removes all socket handlers', () {
    service.startListening();
    service.dispose();
    expect(socket.hasHandler('dice_rolled'),  isFalse);
    expect(socket.hasHandler('pawn_moved'),   isFalse);
    expect(socket.hasHandler('turn_changed'), isFalse);
  });

  test('24 — dispose is safe to call without startListening', () {
    expect(() => service.dispose(), returnsNormally);
  });

  test('25 — dispose is idempotent (safe to call twice)', () {
    service.startListening();
    service.dispose();
    expect(() => service.dispose(), returnsNormally);
  });

  test('26 — events are not delivered after dispose', () async {
    service.startListening();
    service.dispose();

    var received = false;
    // Streams are closed — listening would error, but we verify no event fires.
    // After dispose the controllers are closed; no events can be delivered.
    try {
      service.onDiceRolled.listen((_) => received = true);
    } catch (_) {
      // Expected — stream is closed; this is acceptable behaviour.
    }

    socket.simulateEvent('dice_rolled', {
      'matchId': kMatchId, 'color': 'red', 'value': 1, 'validMoves': [],
    });
    await Future<void>.delayed(Duration.zero);

    expect(received, isFalse);
  });

  // ── GameException ──────────────────────────────────────────────────────────

  test('27 — GameException.toString includes the message', () {
    const ex = GameException('dice roll failed');
    expect(ex.toString(), contains('dice roll failed'));
  });
}
