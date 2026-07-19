import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/game_over.dart';
import 'package:one_minute_ludo/features/game/screens/game_screen.dart';
import 'package:one_minute_ludo/features/matchmaking/models/game_started.dart';
import 'package:one_minute_ludo/features/matchmaking/models/match_found.dart';
import 'package:one_minute_ludo/features/matchmaking/models/opponent.dart';
import 'package:one_minute_ludo/features/matchmaking/services/game_lobby_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';
import 'package:one_minute_ludo/features/matchmaking/models/room_ready.dart';

// ── Fake SocketClient ─────────────────────────────────────────────────────────

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

  void simulateEvent(String event, dynamic data) {
    final listeners = List<void Function(dynamic)>.from(
      _handlers[event] ?? const [],
    );
    for (final fn in listeners) {
      fn(data);
    }
  }
}

// ── Fake GameLobbyService ─────────────────────────────────────────────────────

class _FakeGameLobbyService extends GameLobbyService {
  _FakeGameLobbyService(this._fakeSocket)
      : super(socketClient: _fakeSocket);

  final _FakeSocketClient _fakeSocket;

  final _gameOverCtrl = StreamController<GameOver>.broadcast();

  @override
  Stream<RoomReady>   get onRoomReady  => const Stream.empty();
  @override
  Stream<String>      get onOpponentLeft => const Stream.empty();
  @override
  Stream<GameStarted> get onGameStart  => const Stream.empty();
  @override
  Stream<GameOver>    get onGameOver   => _gameOverCtrl.stream;

  @override
  Future<void> joinRoom(String matchId) async {}

  @override
  void forfeit(String matchId) {
    _fakeSocket.emit('forfeit', {'matchId': matchId});
  }

  @override
  void leaveRoom(String matchId) {}

  @override
  void dispose() {
    if (!_gameOverCtrl.isClosed) _gameOverCtrl.close();
  }

  void simulateGameOver(String matchId, String winnerId, String reason) =>
      _gameOverCtrl.add(
        GameOver(matchId: matchId, winnerId: winnerId, reason: reason),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kMatchFound = MatchFound(
  matchId:  'match-uuid-1',
  roomCode: 'ABC123',
  color:    'blue',
  opponent: Opponent(
    playerId: 'LUD-OPP001',
    fullName: 'Opponent Player',
  ),
);

const _kGameStarted = GameStarted(
  matchId:   'match-uuid-1',
  firstTurn: 'red',
);

/// Returns a [_FakeGameLobbyService] so tests can simulate events.
Future<_FakeGameLobbyService> _pump(
  WidgetTester tester, {
  GameStarted?                       gameStarted,
  MatchFound?                        matchFound,
  void Function(GameOver)?           onGameOver,
  VoidCallback?                      onSessionExpired,
  _FakeGameLobbyService?             gameLobbyService,
}) async {
  final socket = _FakeSocketClient();
  final svc    = gameLobbyService ?? _FakeGameLobbyService(socket);

  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        gameLobbyService: svc,
        gameStarted:      gameStarted      ?? _kGameStarted,
        matchFound:       matchFound       ?? _kMatchFound,
        onGameOver:       onGameOver       ?? (_) {},
        onSessionExpired: onSessionExpired ?? () {},
      ),
    ),
  );
  return svc;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Smoke ──────────────────────────────────────────────────────────────────

  testWidgets('1 — smoke: renders without crashing', (tester) async {
    await _pump(tester);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  // ── AppBar ─────────────────────────────────────────────────────────────────

  testWidgets('2 — AppBar is present with game_screen_app_bar key',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('game_screen_app_bar')), findsOneWidget);
  });

  testWidgets('3 — AppBar title shows "Game"', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('game_screen_app_bar')),
        matching: find.text('Game'),
      ),
      findsOneWidget,
    );
  });

  // ── First turn banner ──────────────────────────────────────────────────────

  testWidgets('4 — first_turn_banner widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('first_turn_banner')), findsOneWidget);
  });

  testWidgets('5 — first turn banner shows correct colour (RED first turn)',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('first_turn_text')), findsOneWidget);
    // opponent goes first (red ≠ my color blue)
    expect(find.textContaining('RED'), findsOneWidget);
  });

  testWidgets('6 — first turn banner says "You go first" when it is my turn',
      (tester) async {
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound, // my color is blue
    );
    expect(find.textContaining('You go first'), findsOneWidget);
  });

  testWidgets(
      '7 — first turn banner says "Opponent goes first" when it is not my turn',
      (tester) async {
    // my color is blue, firstTurn is red → opponent goes first
    await _pump(tester);
    expect(find.textContaining('Opponent goes first'), findsOneWidget);
  });

  // ── Match information card ─────────────────────────────────────────────────

  testWidgets('8 — match_info_card widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('match_info_card')), findsOneWidget);
  });

  testWidgets('9 — opponent name is shown in match info card', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('opponent_name')), findsOneWidget);
    expect(find.text('Opponent Player'), findsOneWidget);
  });

  testWidgets('10 — my colour chip is shown', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('my_color_chip')), findsOneWidget);
    expect(find.text('BLUE'), findsOneWidget);
  });

  testWidgets('11 — room code is shown', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('room_code')), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  // ── Placeholder board ──────────────────────────────────────────────────────

  testWidgets('12 — placeholder_board widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('placeholder_board')), findsOneWidget);
  });

  testWidgets(
      '13 — placeholder board shows "Board coming in Phase 6" text',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('placeholder_board_text')), findsOneWidget);
    expect(find.textContaining('Phase 6'), findsOneWidget);
  });

  // ── Forfeit button (Phase 5.6) ─────────────────────────────────────────────

  testWidgets('14 — forfeit_button widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('forfeit_button')), findsOneWidget);
  });

  testWidgets('15 — tapping forfeit button emits forfeit event via service',
      (tester) async {
    final socket = _FakeSocketClient();
    final svc    = _FakeGameLobbyService(socket);
    await _pump(tester, gameLobbyService: svc);

    await tester.tap(find.byKey(const Key('forfeit_button')));
    await tester.pump();

    expect(socket.emittedEvents, contains('forfeit'));
    final idx  = socket.emittedEvents.indexOf('forfeit');
    final data = socket.emittedData[idx] as Map;
    expect(data['matchId'], 'match-uuid-1');
  });

  testWidgets('16 — forfeit button shows spinner while forfeiting',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('forfeit_button')));
    await tester.pump();

    expect(find.byKey(const Key('forfeit_spinner')), findsOneWidget);
  });

  testWidgets('17 — forfeit button is disabled after tapping',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('forfeit_button')));
    await tester.pump();

    final btn = tester.widget<OutlinedButton>(
      find.byKey(const Key('forfeit_button')),
    );
    expect(btn.onPressed, isNull);
  });

  // ── Game-over overlay (Phase 5.6) ──────────────────────────────────────────

  testWidgets('18 — game_over_overlay is absent before game ends',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('game_over_overlay')), findsNothing);
  });

  testWidgets('19 — game_over_overlay appears when game_over event fires',
      (tester) async {
    final svc = await _pump(tester);

    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_overlay')), findsOneWidget);
  });

  testWidgets('20 — game_over_card is shown inside overlay', (tester) async {
    final svc = await _pump(tester);

    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_card')), findsOneWidget);
  });

  testWidgets('21 — game_over_title is shown', (tester) async {
    final svc = await _pump(tester);

    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_title')), findsOneWidget);
  });

  testWidgets('22 — game_over_subtitle is shown', (tester) async {
    final svc = await _pump(tester);

    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_subtitle')), findsOneWidget);
  });

  testWidgets('23 — game_over_continue_button is present', (tester) async {
    final svc = await _pump(tester);

    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_continue_button')), findsOneWidget);
  });

  testWidgets('24 — tapping CONTINUE fires onGameOver callback',
      (tester) async {
    GameOver? received;
    final svc = await _pump(
      tester,
      onGameOver: (e) => received = e,
    );

    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    await tester.tap(find.byKey(const Key('game_over_continue_button')));
    await tester.pump();

    expect(received, isNotNull);
    expect(received!.matchId,  'match-uuid-1');
    expect(received!.winnerId, 'winner-id');
    expect(received!.reason,   'forfeit');
  });

  testWidgets('25 — overlay forfeit button becomes disabled after game_over',
      (tester) async {
    final svc = await _pump(tester);

    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    final btn = tester.widget<OutlinedButton>(
      find.byKey(const Key('forfeit_button')),
    );
    expect(btn.onPressed, isNull);
  });
}
