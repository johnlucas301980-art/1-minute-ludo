import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/features/matchmaking/models/match_found.dart';
import 'package:one_minute_ludo/features/matchmaking/models/opponent.dart';
import 'package:one_minute_ludo/features/matchmaking/models/room_ready.dart';
import 'package:one_minute_ludo/features/matchmaking/screens/game_lobby_screen.dart';
import 'package:one_minute_ludo/features/matchmaking/services/game_lobby_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';

// ── Fake GameLobbyService ─────────────────────────────────────────────────────

/// Test-only [GameLobbyService] subclass that never touches real I/O.
///
/// - [joinRoomException] — if set, [joinRoom] throws it immediately.
/// - Otherwise [joinRoom] completes normally (simulating a fast server ack).
/// - [simulateRoomReady] / [simulateOpponentLeft] push events to the streams.
class _FakeGameLobbyService extends GameLobbyService {
  _FakeGameLobbyService({this.joinRoomException})
      : super(socketClient: _FakeSocketClient());

  Exception? joinRoomException;

  bool joinRoomCalled  = false;
  bool leaveRoomCalled = false;
  String? leaveRoomMatchId;

  final _roomReadyCtrl    = StreamController<RoomReady>.broadcast();
  final _opponentLeftCtrl = StreamController<String>.broadcast();

  @override
  Stream<RoomReady> get onRoomReady    => _roomReadyCtrl.stream;

  @override
  Stream<String>   get onOpponentLeft => _opponentLeftCtrl.stream;

  @override
  Future<void> joinRoom(String matchId) async {
    joinRoomCalled = true;
    if (joinRoomException != null) throw joinRoomException!;
  }

  @override
  void leaveRoom(String matchId) {
    leaveRoomCalled  = true;
    leaveRoomMatchId = matchId;
  }

  @override
  void dispose() {
    _roomReadyCtrl.close();
    _opponentLeftCtrl.close();
  }

  void simulateRoomReady(String matchId) =>
      _roomReadyCtrl.add(RoomReady(matchId: matchId));

  void simulateOpponentLeft(String matchId) =>
      _opponentLeftCtrl.add(matchId);
}

// ── Fake SocketClient ─────────────────────────────────────────────────────────

class _FakeSocketClient extends SocketClient {
  _FakeSocketClient() : super(tokenProvider: () async => 'fake-token');

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void emit(String event, [dynamic data]) {}

  @override
  void on(String event, void Function(dynamic) handler) {}

  @override
  void off(String event) {}

  @override
  void dispose() {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kMatchId  = 'match-uuid-1';
const _kRoomCode = 'ABC123';
const _kColor    = 'blue';

const _kMatchFound = MatchFound(
  matchId:  _kMatchId,
  roomCode: _kRoomCode,
  color:    _kColor,
  opponent: Opponent(
    playerId: 'LUD-OPP001',
    fullName: 'Opponent Player',
  ),
);

Future<_FakeGameLobbyService> _pump(
  WidgetTester tester, {
  _FakeGameLobbyService? service,
  MatchFound? matchFound,
  VoidCallback? onSessionExpired,
  VoidCallback? onLeaveRoom,
}) async {
  final svc = service ?? _FakeGameLobbyService();

  await tester.pumpWidget(
    MaterialApp(
      home: GameLobbyScreen(
        gameLobbyService: svc,
        matchFound:       matchFound ?? _kMatchFound,
        onSessionExpired: onSessionExpired ?? () {},
        onLeaveRoom:      onLeaveRoom ?? () {},
      ),
    ),
  );
  return svc;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Smoke / joining state ──────────────────────────────────────────────────

  testWidgets('1 — smoke: renders without crashing', (tester) async {
    await _pump(tester);
    expect(find.byType(GameLobbyScreen), findsOneWidget);
  });

  testWidgets('2 — shows joining state initially (spinner visible)',
      (tester) async {
    // Use a service that never completes joinRoom.
    final svc = _FakeGameLobbyService();

    // Override joinRoom to block so the screen stays in joining state.
    // We test by pumping before the future resolves.
    await tester.pumpWidget(
      MaterialApp(
        home: GameLobbyScreen(
          gameLobbyService: svc,
          matchFound:       _kMatchFound,
          onSessionExpired: () {},
          onLeaveRoom:      () {},
        ),
      ),
    );
    // Only pump the first frame — _joinRoom is in flight.
    expect(find.byKey(const Key('joining_view')),   findsOneWidget);
    expect(find.byKey(const Key('joining_spinner')), findsOneWidget);
    await tester.pump(); // drain joinRoom Future
  });

  // ── Waiting state ──────────────────────────────────────────────────────────

  testWidgets('3 — shows waiting state after joinRoom completes', (tester) async {
    await _pump(tester);
    await tester.pump(); // drain joinRoom Future
    expect(find.byKey(const Key('waiting_view')), findsOneWidget);
    expect(find.byKey(const Key('waiting_text')), findsOneWidget);
  });

  testWidgets('4 — opponent name is shown in waiting state', (tester) async {
    await _pump(tester);
    await tester.pump();
    expect(find.byKey(const Key('opponent_name')), findsOneWidget);
    expect(find.text('Opponent Player'), findsOneWidget);
  });

  testWidgets('5 — room code is shown in waiting state', (tester) async {
    await _pump(tester);
    await tester.pump();
    expect(find.byKey(const Key('room_code')),        findsOneWidget);
    expect(find.textContaining('ABC123'), findsOneWidget);
  });

  testWidgets('6 — assigned color chip is shown in waiting state', (tester) async {
    await _pump(tester);
    await tester.pump();
    expect(find.byKey(const Key('assigned_color')), findsOneWidget);
    expect(find.text('BLUE'), findsOneWidget);
  });

  testWidgets('7 — leave lobby button is visible in waiting state', (tester) async {
    await _pump(tester);
    await tester.pump();
    expect(find.byKey(const Key('leave_lobby_button')), findsOneWidget);
  });

  testWidgets('8 — joinRoom is called in initState', (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, service: svc);
    await tester.pump();
    expect(svc.joinRoomCalled, isTrue);
  });

  // ── Ready state ────────────────────────────────────────────────────────────

  testWidgets('9 — room_ready event transitions to ready state', (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, service: svc);
    await tester.pump(); // waiting

    svc.simulateRoomReady(_kMatchId);
    await tester.pump(); // setState → ready

    expect(find.byKey(const Key('ready_view')), findsOneWidget);
    expect(find.byKey(const Key('ready_text')), findsOneWidget);
  });

  testWidgets('10 — ready state shows "Room Ready!" text', (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, service: svc);
    await tester.pump();

    svc.simulateRoomReady(_kMatchId);
    await tester.pump();

    expect(find.text('Room Ready!'), findsOneWidget);
  });

  testWidgets('11 — ready state shows match info card', (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, service: svc);
    await tester.pump();

    svc.simulateRoomReady(_kMatchId);
    await tester.pump();

    expect(find.byKey(const Key('match_info_card')), findsOneWidget);
    expect(find.byKey(const Key('opponent_name')),   findsOneWidget);
  });

  testWidgets('12 — ready state shows start game button (disabled)', (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, service: svc);
    await tester.pump();

    svc.simulateRoomReady(_kMatchId);
    await tester.pump();

    expect(find.byKey(const Key('start_game_button')), findsOneWidget);
  });

  // ── Opponent left state ────────────────────────────────────────────────────

  testWidgets('13 — opponent_left event transitions to opponentLeft state',
      (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, service: svc);
    await tester.pump();

    svc.simulateOpponentLeft(_kMatchId);
    await tester.pump();

    expect(find.byKey(const Key('opponent_left_view')),   findsOneWidget);
    expect(find.byKey(const Key('opponent_left_banner')), findsOneWidget);
  });

  testWidgets('14 — opponent left state shows leave lobby button', (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, service: svc);
    await tester.pump();

    svc.simulateOpponentLeft(_kMatchId);
    await tester.pump();

    expect(find.byKey(const Key('leave_lobby_button')), findsOneWidget);
  });

  // ── Leave lobby ────────────────────────────────────────────────────────────

  testWidgets('15 — tapping leave button fires onLeaveRoom callback', (tester) async {
    var leaveRoomCalled = false;
    await _pump(tester, onLeaveRoom: () => leaveRoomCalled = true);
    await tester.pump();

    await tester.tap(find.byKey(const Key('leave_lobby_button')));
    await tester.pump();

    expect(leaveRoomCalled, isTrue);
  });

  testWidgets('16 — tapping AppBar back button fires onLeaveRoom callback',
      (tester) async {
    var leaveRoomCalled = false;
    await _pump(tester, onLeaveRoom: () => leaveRoomCalled = true);
    await tester.pump();

    await tester.tap(find.byKey(const Key('leave_button')));
    await tester.pump();

    expect(leaveRoomCalled, isTrue);
  });

  // ── Error / session expiry ─────────────────────────────────────────────────

  testWidgets('17 — SessionExpiredException calls onSessionExpired', (tester) async {
    var sessionExpiredCalled = false;
    final svc = _FakeGameLobbyService(
      joinRoomException: SessionExpiredException(),
    );

    await _pump(
      tester,
      service:          svc,
      onSessionExpired: () => sessionExpiredCalled = true,
    );
    await tester.pump(); // drain joinRoom Future

    expect(sessionExpiredCalled, isTrue);
  });

  testWidgets('18 — GameLobbyException shows error state', (tester) async {
    final svc = _FakeGameLobbyService(
      joinRoomException: const GameLobbyException('You are not a player in this match.'),
    );

    await _pump(tester, service: svc);
    await tester.pump();

    expect(find.byKey(const Key('error_view')),    findsOneWidget);
    expect(find.byKey(const Key('error_banner')),  findsOneWidget);
    expect(
      find.textContaining('You are not a player in this match.'),
      findsOneWidget,
    );
  });

  testWidgets('19 — error state shows leave lobby button', (tester) async {
    final svc = _FakeGameLobbyService(
      joinRoomException: const GameLobbyException('Match not found.'),
    );

    await _pump(tester, service: svc);
    await tester.pump();

    expect(find.byKey(const Key('leave_lobby_button')), findsOneWidget);
  });
}
