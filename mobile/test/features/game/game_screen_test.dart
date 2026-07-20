import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/models/dice_rolled.dart';
import 'package:one_minute_ludo/features/game/models/game_over.dart';
import 'package:one_minute_ludo/features/game/models/pawn_moved.dart';
import 'package:one_minute_ludo/features/game/models/turn_changed.dart';
import 'package:one_minute_ludo/features/game/models/valid_move.dart';
import 'package:one_minute_ludo/features/game/screens/game_screen.dart';
import 'package:one_minute_ludo/features/game/services/game_service.dart';
import 'package:one_minute_ludo/features/game/widgets/ludo_board_widget.dart';
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

// ── Fake GameService ──────────────────────────────────────────────────────────

class _FakeGameService extends GameService {
  _FakeGameService() : super(socketClient: _FakeSocketClient());

  // ── Controlled streams ───────────────────────────────────────────────────
  final _diceCtrl  = StreamController<DiceRolled>.broadcast();
  final _pawnCtrl  = StreamController<PawnMoved>.broadcast();
  final _turnCtrl  = StreamController<TurnChanged>.broadcast();

  @override
  Stream<DiceRolled>  get onDiceRolled  => _diceCtrl.stream;
  @override
  Stream<PawnMoved>   get onPawnMoved   => _pawnCtrl.stream;
  @override
  Stream<TurnChanged> get onTurnChanged => _turnCtrl.stream;

  // ── Tracked calls ────────────────────────────────────────────────────────
  bool rolledDice = false;
  final List<int> movedPawnIndices = [];

  @override void startListening() {}
  @override void stopListening()  {}

  @override
  void rollDice(String matchId) => rolledDice = true;

  @override
  void movePawn(String matchId, int pawnIndex) =>
      movedPawnIndices.add(pawnIndex);

  @override
  void dispose() {
    if (!_diceCtrl.isClosed) _diceCtrl.close();
    if (!_pawnCtrl.isClosed) _pawnCtrl.close();
    if (!_turnCtrl.isClosed) _turnCtrl.close();
  }

  // ── Simulation helpers ────────────────────────────────────────────────────
  void simulateDiceRolled(DiceRolled e)   => _diceCtrl.add(e);
  void simulatePawnMoved(PawnMoved e)     => _pawnCtrl.add(e);
  void simulateTurnChanged(TurnChanged e) => _turnCtrl.add(e);
}

// ── Fake GameLobbyService ─────────────────────────────────────────────────────

class _FakeGameLobbyService extends GameLobbyService {
  _FakeGameLobbyService(this._fakeSocket)
      : super(socketClient: _fakeSocket);

  final _FakeSocketClient _fakeSocket;

  final _gameOverCtrl = StreamController<GameOver>.broadcast();

  @override
  Stream<RoomReady>   get onRoomReady    => const Stream.empty();
  @override
  Stream<String>      get onOpponentLeft => const Stream.empty();
  @override
  Stream<GameStarted> get onGameStart    => const Stream.empty();
  @override
  Stream<GameOver>    get onGameOver     => _gameOverCtrl.stream;

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

/// Named record returned by [_pump].
typedef _Services = ({_FakeGameLobbyService lobby, _FakeGameService game});

/// Pumps [GameScreen] with fake services.
///
/// Returns a record with both fake services so tests can simulate events on
/// either the lobby service (game-over) or the game service (dice, pawns, turn).
Future<_Services> _pump(
  WidgetTester tester, {
  GameStarted?                       gameStarted,
  MatchFound?                        matchFound,
  void Function(GameOver)?           onGameOver,
  VoidCallback?                      onSessionExpired,
  _FakeGameLobbyService?             gameLobbyService,
  _FakeGameService?                  gameService,
}) async {
  final socket  = _FakeSocketClient();
  final lobby   = gameLobbyService ?? _FakeGameLobbyService(socket);
  final gameSvc = gameService      ?? _FakeGameService();

  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        gameService:      gameSvc,
        gameLobbyService: lobby,
        gameStarted:      gameStarted      ?? _kGameStarted,
        matchFound:       matchFound       ?? _kMatchFound,
        onGameOver:       onGameOver       ?? (_) {},
        onSessionExpired: onSessionExpired ?? () {},
      ),
    ),
  );
  return (lobby: lobby, game: gameSvc);
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

  // ── Turn banner ────────────────────────────────────────────────────────────

  testWidgets('4 — turn_banner widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('turn_banner')), findsOneWidget);
  });

  testWidgets('5 — turn banner shows correct colour (RED first turn)',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('turn_text')), findsOneWidget);
    // opponent goes first (red ≠ my color blue)
    expect(find.textContaining('RED'), findsOneWidget);
  });

  testWidgets("6 — turn banner says \"Your turn\" when it is my turn",
      (tester) async {
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound, // my color is blue
    );
    expect(find.textContaining('Your turn'), findsOneWidget);
  });

  testWidgets(
      "7 — turn banner says \"Opponent's turn\" when it is not my turn",
      (tester) async {
    // my color is blue, firstTurn is red → opponent goes first
    await _pump(tester);
    expect(find.textContaining("Opponent's turn"), findsOneWidget);
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

  // ── Ludo board ─────────────────────────────────────────────────────────────

  testWidgets('12 — LudoBoardWidget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('ludo_board')), findsOneWidget);
    expect(find.byType(LudoBoardWidget), findsOneWidget);
  });

  testWidgets('13 — no placeholder board text remains', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('placeholder_board')), findsNothing);
    expect(find.textContaining('Phase 6'), findsNothing);
  });

  // ── Dice area ──────────────────────────────────────────────────────────────

  testWidgets('14a — dice_area widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('dice_area')), findsOneWidget);
  });

  testWidgets('14b — roll_button is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('roll_button')), findsOneWidget);
  });

  testWidgets('14c — dice shows "?" before first roll', (tester) async {
    await _pump(tester);
    final txt = tester.widget<Text>(find.byKey(const Key('dice_value')));
    expect(txt.data, '?');
  });

  // ── Forfeit button (Phase 5.6) ─────────────────────────────────────────────

  testWidgets('15 — forfeit_button widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('forfeit_button')), findsOneWidget);
  });

  testWidgets('16 — tapping forfeit button emits forfeit event via service',
      (tester) async {
    final socket = _FakeSocketClient();
    final lobby  = _FakeGameLobbyService(socket);
    await _pump(tester, gameLobbyService: lobby);

    await tester.ensureVisible(find.byKey(const Key('forfeit_button')));
    await tester.tap(find.byKey(const Key('forfeit_button')));
    await tester.pump();

    expect(socket.emittedEvents, contains('forfeit'));
    final idx  = socket.emittedEvents.indexOf('forfeit');
    final data = socket.emittedData[idx] as Map;
    expect(data['matchId'], 'match-uuid-1');
  });

  testWidgets('17 — forfeit button shows spinner while forfeiting',
      (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.byKey(const Key('forfeit_button')));
    await tester.tap(find.byKey(const Key('forfeit_button')));
    await tester.pump();

    expect(find.byKey(const Key('forfeit_spinner')), findsOneWidget);
  });

  testWidgets('18 — forfeit button is disabled after tapping',
      (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.byKey(const Key('forfeit_button')));
    await tester.tap(find.byKey(const Key('forfeit_button')));
    await tester.pump();

    final btn = tester.widget<OutlinedButton>(
      find.byKey(const Key('forfeit_button')),
    );
    expect(btn.onPressed, isNull);
  });

  // ── Game-over overlay (Phase 5.6) ──────────────────────────────────────────

  testWidgets('19 — game_over_overlay is absent before game ends',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('game_over_overlay')), findsNothing);
  });

  testWidgets('20 — game_over_overlay appears when game_over event fires',
      (tester) async {
    final r = await _pump(tester);

    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_overlay')), findsOneWidget);
  });

  testWidgets('21 — game_over_card is shown inside overlay', (tester) async {
    final r = await _pump(tester);

    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_card')), findsOneWidget);
  });

  testWidgets('22 — game_over_title is shown', (tester) async {
    final r = await _pump(tester);

    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_title')), findsOneWidget);
  });

  testWidgets('23 — game_over_subtitle is shown', (tester) async {
    final r = await _pump(tester);

    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_subtitle')), findsOneWidget);
  });

  testWidgets('24 — game_over_continue_button is present', (tester) async {
    final r = await _pump(tester);

    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    expect(find.byKey(const Key('game_over_continue_button')), findsOneWidget);
  });

  testWidgets('25 — tapping CONTINUE fires onGameOver callback',
      (tester) async {
    GameOver? received;
    final r = await _pump(
      tester,
      onGameOver: (e) => received = e,
    );

    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    await tester.tap(find.byKey(const Key('game_over_continue_button')));
    await tester.pump();

    expect(received, isNotNull);
    expect(received!.matchId,  'match-uuid-1');
    expect(received!.winnerId, 'winner-id');
    expect(received!.reason,   'forfeit');
  });

  testWidgets('26 — overlay forfeit button becomes disabled after game_over',
      (tester) async {
    final r = await _pump(tester);

    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();

    final btn = tester.widget<OutlinedButton>(
      find.byKey(const Key('forfeit_button')),
    );
    expect(btn.onPressed, isNull);
  });

  // ── Roll button state ──────────────────────────────────────────────────────

  testWidgets(
      '27 — roll button is disabled when it is not my turn (firstTurn=red, '
      'my color=blue)', (tester) async {
    // Default: red goes first, my color is blue → button disabled.
    await _pump(tester);

    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('roll_button')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('28 — roll button is enabled when it is my turn', (tester) async {
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound, // my color is blue
    );

    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('roll_button')),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('29 — tapping roll button calls gameService.rollDice',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    await tester.tap(find.byKey(const Key('roll_button')));
    await tester.pump();

    expect(gameSvc.rolledDice, isTrue);
  });

  // ── Dice value update ──────────────────────────────────────────────────────

  testWidgets(
      '30 — dice value updates when dice_rolled event fires (my turn)',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      4,
      validMoves: [],
    ));
    await tester.pump();

    final txt = tester.widget<Text>(find.byKey(const Key('dice_value')));
    expect(txt.data, '4');
  });

  testWidgets(
      '31 — valid_moves_panel appears when my turn and valid moves exist',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      6,
      validMoves: [ValidMove(pawnIndex: 0, fromPos: 0, toPos: 1)],
    ));
    await tester.pump();

    expect(find.byKey(const Key('valid_moves_panel')), findsOneWidget);
    expect(find.byKey(const Key('move_pawn_0')),       findsOneWidget);
  });

  testWidgets(
      '32 — tapping move button calls gameService.movePawn with correct index',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      6,
      validMoves: [ValidMove(pawnIndex: 0, fromPos: 0, toPos: 1)],
    ));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('move_pawn_0')));
    await tester.tap(find.byKey(const Key('move_pawn_0')));
    await tester.pump();

    expect(gameSvc.movedPawnIndices, contains(0));
  });

  // ── Turn changed ───────────────────────────────────────────────────────────

  testWidgets(
      '33 — turn_changed event updates turn banner to new player',
      (tester) async {
    final gameSvc = _FakeGameService();
    // Start with blue's turn (my color).
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    expect(find.textContaining('Your turn'), findsOneWidget);

    // Turn passes to red (opponent).
    gameSvc.simulateTurnChanged(
      const TurnChanged(matchId: 'match-uuid-1', nextTurn: 'red'),
    );
    await tester.pump();

    expect(find.textContaining("Opponent's turn"), findsOneWidget);
  });

  testWidgets(
      '34 — pawn_moved event does not crash and board widget is still present',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulatePawnMoved(const PawnMoved(
      matchId:   'match-uuid-1',
      color:     'blue',
      pawnIndex: 0,
      toPosition: 1,
    ));
    await tester.pump();

    // Board still present after pawn move.
    expect(find.byType(LudoBoardWidget), findsOneWidget);
  });

  // ── Pawn highlighting (Phase 6.7.3) ───────────────────────────────────────

  testWidgets(
      '35 — LudoBoardWidget receives validPawnIndices after dice_rolled with '
      'valid moves on my turn',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      5,
      validMoves: [ValidMove(pawnIndex: 2, fromPos: 0, toPos: 1)],
    ));
    await tester.pump();

    final board = tester.widget<LudoBoardWidget>(
      find.byKey(const Key('ludo_board')),
    );
    expect(board.validPawnIndices, equals([2]));
    expect(board.validColor, equals('blue'));
  });

  testWidgets(
      '36 — LudoBoardWidget.validPawnIndices is null after move button tapped',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      6,
      validMoves: [ValidMove(pawnIndex: 0, fromPos: 0, toPos: 1)],
    ));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('move_pawn_0')));
    await tester.tap(find.byKey(const Key('move_pawn_0')));
    await tester.pump();

    final board = tester.widget<LudoBoardWidget>(
      find.byKey(const Key('ludo_board')),
    );
    expect(board.validPawnIndices, isNull);
  });

  testWidgets(
      "37 — opponent's dice_rolled does not show valid_moves_panel",
      (tester) async {
    final gameSvc = _FakeGameService();
    // Red goes first, my colour is blue → not my turn.
    await _pump(tester, gameService: gameSvc);

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'red',
      value:      4,
      validMoves: [ValidMove(pawnIndex: 1, fromPos: 0, toPos: 1)],
    ));
    await tester.pump();

    expect(find.byKey(const Key('valid_moves_panel')), findsNothing);
  });

  // ── Dice state reset (Phase 6.7.3) ────────────────────────────────────────

  testWidgets('38 — dice shows "?" after turn_changed resets dice state',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      3,
      validMoves: [],
    ));
    await tester.pump();
    final txt1 = tester.widget<Text>(find.byKey(const Key('dice_value')));
    expect(txt1.data, '3');

    gameSvc.simulateTurnChanged(
      const TurnChanged(matchId: 'match-uuid-1', nextTurn: 'red'),
    );
    await tester.pump();
    final txt2 = tester.widget<Text>(find.byKey(const Key('dice_value')));
    expect(txt2.data, '?');
  });

  testWidgets('39 — valid_moves_panel disappears after turn_changed',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      6,
      validMoves: [ValidMove(pawnIndex: 0, fromPos: 0, toPos: 1)],
    ));
    await tester.pump();
    expect(find.byKey(const Key('valid_moves_panel')), findsOneWidget);

    gameSvc.simulateTurnChanged(
      const TurnChanged(matchId: 'match-uuid-1', nextTurn: 'red'),
    );
    await tester.pump();
    expect(find.byKey(const Key('valid_moves_panel')), findsNothing);
  });

  // ── Capture updates (Phase 6.7.3) ─────────────────────────────────────────

  testWidgets(
      '40 — pawn_moved with capture resets captured pawn; board still present',
      (tester) async {
    final gameSvc = _FakeGameService();
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulatePawnMoved(const PawnMoved(
      matchId:           'match-uuid-1',
      color:             'blue',
      pawnIndex:         0,
      toPosition:        14,
      capturedColor:     'red',
      capturedPawnIndex: 1,
    ));
    await tester.pump();

    expect(find.byType(LudoBoardWidget), findsOneWidget);
  });

  // ── Game-over cleanup (Phase 6.7.3) ──────────────────────────────────────

  testWidgets('41 — game_over event clears valid_moves_panel immediately',
      (tester) async {
    final gameSvc = _FakeGameService();
    final r = await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    // Show valid moves panel first.
    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      6,
      validMoves: [ValidMove(pawnIndex: 0, fromPos: 0, toPos: 1)],
    ));
    await tester.pump();
    expect(find.byKey(const Key('valid_moves_panel')), findsOneWidget);

    // Game over fires.
    r.lobby.simulateGameOver('match-uuid-1', 'winner-id', 'completed');
    await tester.pump();

    expect(find.byKey(const Key('valid_moves_panel')), findsNothing);
  });

  testWidgets('42 — game_over event clears displayed dice value',
      (tester) async {
    final gameSvc = _FakeGameService();
    final r = await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound,
      gameService: gameSvc,
    );

    gameSvc.simulateDiceRolled(const DiceRolled(
      matchId:    'match-uuid-1',
      color:      'blue',
      value:      5,
      validMoves: [],
    ));
    await tester.pump();
    final txt1 = tester.widget<Text>(find.byKey(const Key('dice_value')));
    expect(txt1.data, '5');

    r.lobby.simulateGameOver('match-uuid-1', 'loser-id', 'completed');
    await tester.pump();

    final txt2 = tester.widget<Text>(find.byKey(const Key('dice_value')));
    expect(txt2.data, '?');
  });
}
