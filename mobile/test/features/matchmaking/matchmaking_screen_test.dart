import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/matchmaking/models/match_found.dart';
import 'package:one_minute_ludo/features/matchmaking/screens/matchmaking_screen.dart';
import 'package:one_minute_ludo/features/matchmaking/services/matchmaking_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';

// ── Fake SocketClient ─────────────────────────────────────────────────────────

/// A test-only [SocketClient] subclass that never opens a real network
/// connection.  Handlers registered via [on] are stored in-process so
/// [simulateEvent] can fire them synchronously.
class _FakeSocketClient extends SocketClient {
  _FakeSocketClient()
      : super(tokenProvider: () async => 'fake-access-token');

  bool _connected = false;
  bool shouldFailConnect = false;
  String connectErrorMessage = 'Connection failed';

  final Map<String, List<void Function(dynamic)>> _handlers = {};

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    if (shouldFailConnect) {
      throw SocketConnectionException(connectErrorMessage);
    }
    _connected = true;
  }

  @override
  void disconnect() {
    _connected = false;
  }

  @override
  void emit(String event, [dynamic data]) {}

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

  /// Deliver a fake incoming socket event to all registered listeners.
  void simulateEvent(String event, dynamic data) {
    final listeners = List<void Function(dynamic)>.from(
      _handlers[event] ?? const [],
    );
    for (final listener in listeners) {
      listener(data);
    }
  }
}

// ── Fake ApiClient ────────────────────────────────────────────────────────────

ApiClient _makeStubApiClient() => ApiClient(
      tokenStorage: const TokenStorage(),
      httpClient: MockClient(
        (_) async => http.Response('{"success":true,"data":{}}', 200),
      ),
    );

// ── Fake MatchmakingService ───────────────────────────────────────────────────

/// Test-only subclass that uses a [_FakeSocketClient] so no real I/O occurs.
///
/// - If [joinQueueException] is set, [joinQueue] throws it immediately.
/// - Otherwise, [joinQueue] calls [super.joinQueue], which registers the base
///   class's private [_handleMatchFound] handler on the fake socket.  Calling
///   [simulateMatchFound] then fires that handler, adding an event to the
///   broadcast stream that [MatchmakingScreen] subscribes to.
class _FakeMatchmakingService extends MatchmakingService {
  _FakeMatchmakingService({
    required _FakeSocketClient socket,
    this.joinQueueException,
  })  : _fakeSocket = socket,
        super(
          apiClient:    _makeStubApiClient(),
          socketClient: socket,
        );

  final _FakeSocketClient _fakeSocket;

  /// When non-null, [joinQueue] throws this instead of connecting.
  Exception? joinQueueException;

  bool leaveQueueCalled = false;

  /// Deliver a fake `match_found` payload through the fake socket so the
  /// base-class handler can parse it and add it to [onMatchFound].
  void simulateMatchFound(Map<String, dynamic> payload) {
    _fakeSocket.simulateEvent('match_found', payload);
  }

  @override
  Future<void> joinQueue() async {
    if (joinQueueException != null) throw joinQueueException!;
    // Calling super registers _handleMatchFound on the fake socket via
    // _socket.on('match_found', ...) in the base-class implementation.
    await super.joinQueue();
  }

  @override
  Future<void> leaveQueue() async {
    leaveQueueCalled = true;
    await super.leaveQueue();
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// A canonical match_found payload that passes [MatchFound.fromJson].
Map<String, dynamic> _matchFoundPayload({
  String matchId  = 'match-uuid-1',
  String roomCode = 'ABC123',
  String color    = 'blue',
  String fullName = 'Opponent Player',
}) =>
    {
      'matchId':  matchId,
      'roomCode': roomCode,
      'color':    color,
      'opponent': {
        'playerId': 'LUD-OPPO01',
        'fullName': fullName,
        'avatar':   null,
      },
    };

/// Pumps a [MatchmakingScreen] inside a [MaterialApp].
Future<_FakeMatchmakingService> _pump(
  WidgetTester tester, {
  _FakeMatchmakingService? service,
  VoidCallback? onSessionExpired,
  void Function(MatchFound)? onMatchReady,
}) async {
  final socket = _FakeSocketClient();
  final svc = service ?? _FakeMatchmakingService(socket: socket);

  await tester.pumpWidget(
    MaterialApp(
      home: MatchmakingScreen(
        matchmakingService: svc,
        onSessionExpired:   onSessionExpired ?? () {},
        onMatchReady:       onMatchReady ?? (_) {},
      ),
    ),
  );
  return svc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  // Install FlutterSecureStorage mock so ApiClient construction never opens a
  // platform channel (even though no authenticated REST calls are made here).
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ── Idle state ──────────────────────────────────────────────────────────────

  testWidgets('1 — smoke: renders in idle state without crashing',
      (tester) async {
    await _pump(tester);
    expect(find.byType(MatchmakingScreen), findsOneWidget);
    expect(find.byKey(const Key('idle_view')), findsOneWidget);
  });

  testWidgets('2 — idle: FIND MATCH button is visible', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('find_match_button')), findsOneWidget);
  });

  testWidgets('3 — idle: branding icon and title are visible', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('home_icon')),  findsOneWidget);
    expect(find.byKey(const Key('home_title')), findsOneWidget);
    expect(find.text('1 Minute Ludo'),          findsOneWidget);
  });

  // ── Searching state ─────────────────────────────────────────────────────────

  testWidgets('4 — tapping FIND MATCH transitions to searching state',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump(); // setState → searching
    await tester.pump(); // joinQueue() completes

    expect(find.byKey(const Key('searching_view')),  findsOneWidget);
    expect(find.byKey(const Key('searching_text')),  findsOneWidget);
    expect(find.byKey(const Key('cancel_button')),   findsOneWidget);

    // Cancel to clean up the periodic timer before the test ends.
    await tester.tap(find.byKey(const Key('cancel_button')));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('5 — elapsed timer starts at 00:00 and increments',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    // Initial display is 00:00.
    expect(find.text('00:00'), findsOneWidget);

    // Advance the fake timer by 3 seconds.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:03'), findsOneWidget);

    // Cancel to clean up the periodic timer.
    await tester.tap(find.byKey(const Key('cancel_button')));
    await tester.pump();
    await tester.pump();
  });

  // ── Cancel ──────────────────────────────────────────────────────────────────

  testWidgets('6 — tapping CANCEL returns to idle state', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('cancel_button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('idle_view')),      findsOneWidget);
    expect(find.byKey(const Key('find_match_button')), findsOneWidget);
  });

  testWidgets('7 — leaveQueue is called when CANCEL is tapped', (tester) async {
    final socket = _FakeSocketClient();
    final service = _FakeMatchmakingService(socket: socket);
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('cancel_button')));
    await tester.pump();
    await tester.pump();

    expect(service.leaveQueueCalled, isTrue);
  });

  // ── Match Found state ───────────────────────────────────────────────────────

  testWidgets('8 — match_found event transitions to match found state',
      (tester) async {
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(socket: socket);
    await _pump(tester, service: service);

    // Start search so the handler is registered on the fake socket.
    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    service.simulateMatchFound(_matchFoundPayload());
    await tester.pump(); // _onMatchFound → setState(matchFound)

    expect(find.byKey(const Key('match_found_view')), findsOneWidget);
    expect(find.byKey(const Key('match_found_text')), findsOneWidget);
  });

  testWidgets('9 — match found: opponent name is displayed', (tester) async {
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(socket: socket);
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    service.simulateMatchFound(
      _matchFoundPayload(fullName: 'Alice Wonderland'),
    );
    await tester.pump();

    // Key('opponent_name') is on the Text widget itself; verify its data.
    final nameWidget = tester.widget<Text>(
      find.byKey(const Key('opponent_name')),
    );
    expect(nameWidget.data, 'Alice Wonderland');
  });

  testWidgets('10 — match found: room code is displayed', (tester) async {
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(socket: socket);
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    service.simulateMatchFound(_matchFoundPayload(roomCode: 'XYZ789'));
    await tester.pump();

    expect(find.byKey(const Key('room_code')), findsOneWidget);
    expect(find.textContaining('XYZ789'),      findsOneWidget);
  });

  testWidgets('11 — match found: assigned color is displayed', (tester) async {
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(socket: socket);
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    service.simulateMatchFound(_matchFoundPayload(color: 'red'));
    await tester.pump();

    expect(find.byKey(const Key('match_color')), findsOneWidget);
    // _ColorChip renders the uppercased color name.
    expect(find.text('RED'), findsOneWidget);
  });

  testWidgets('12 — tapping PLAY resets to idle state', (tester) async {
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(socket: socket);
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    service.simulateMatchFound(_matchFoundPayload());
    await tester.pump();

    expect(find.byKey(const Key('play_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('play_button')));
    await tester.pump();

    expect(find.byKey(const Key('idle_view')),         findsOneWidget);
    expect(find.byKey(const Key('find_match_button')), findsOneWidget);
  });

  // ── Session expired ─────────────────────────────────────────────────────────

  testWidgets(
      '13 — SessionExpiredException during joinQueue calls onSessionExpired',
      (tester) async {
    var callbackFired = false;
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(
      socket:              socket,
      joinQueueException:  SessionExpiredException(),
    );

    await _pump(
      tester,
      service:           service,
      onSessionExpired:  () => callbackFired = true,
    );

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    expect(callbackFired, isTrue);
  });

  // ── Error state ─────────────────────────────────────────────────────────────

  testWidgets(
      '14 — MatchmakingException during joinQueue shows error banner',
      (tester) async {
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(
      socket:             socket,
      joinQueueException: const MatchmakingException('Server unavailable'),
    );
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('error_banner')),  findsOneWidget);
    expect(find.textContaining('Server unavailable'), findsOneWidget);
  });

  testWidgets('15 — tapping TRY AGAIN resets to idle state', (tester) async {
    final socket  = _FakeSocketClient();
    final service = _FakeMatchmakingService(
      socket:             socket,
      joinQueueException: const MatchmakingException('Timeout'),
    );
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const Key('find_match_button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('retry_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry_button')));
    await tester.pump();

    expect(find.byKey(const Key('idle_view')),         findsOneWidget);
    expect(find.byKey(const Key('find_match_button')), findsOneWidget);
  });
}
