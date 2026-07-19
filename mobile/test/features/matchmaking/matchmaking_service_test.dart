import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/matchmaking/models/match_found.dart';
import 'package:one_minute_ludo/features/matchmaking/models/opponent.dart';
import 'package:one_minute_ludo/features/matchmaking/models/queue_status.dart';
import 'package:one_minute_ludo/features/matchmaking/services/matchmaking_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';

// ── Fake SocketClient ─────────────────────────────────────────────────────────

/// A test-only subclass of [SocketClient] that never opens a real network
/// connection.  Tests can:
///  - Check which events were emitted via [emittedEvents].
///  - Control whether [connect] succeeds or throws via [configureConnectFailure].
///  - Programmatically deliver incoming events via [simulateEvent].
class _FakeSocketClient extends SocketClient {
  _FakeSocketClient()
      : super(tokenProvider: () async => 'fake-access-token');

  bool _connectCalled = false;
  bool _connected     = false;

  bool   _shouldFailConnect = false;
  String _connectErrorMsg   = 'Connection failed';

  final List<String>                              emittedEvents = [];
  final Map<String, List<void Function(dynamic)>> _handlers    = {};

  bool get connectCalled => _connectCalled;

  /// Configure [connect] to throw [SocketConnectionException] with [message].
  void configureConnectFailure(String message) {
    _shouldFailConnect = true;
    _connectErrorMsg   = message;
  }

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connectCalled = true;
    if (_shouldFailConnect) {
      throw SocketConnectionException(_connectErrorMsg);
    }
    _connected = true;
  }

  @override
  void disconnect() {
    _connected = false;
  }

  @override
  void emit(String event, [dynamic data]) {
    emittedEvents.add(event);
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

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kValidAccessToken = 'valid-access-token';

/// Build an [ApiClient] backed by a [MockClient] that calls [handler].
ApiClient _makeApiClient(MockClientHandler handler) {
  return ApiClient(
    tokenStorage: const TokenStorage(),
    httpClient:   MockClient(handler),
  );
}

/// Encode a map to a JSON string.
String _json(Map<String, dynamic> body) => jsonEncode(body);

/// Successful queue status response body.
String _queueStatusJson({
  bool    inQueue   = false,
  int     queueSize = 0,
  String? joinedAt,
}) =>
    _json({
      'success': true,
      'data': {
        'inQueue':   inQueue,
        'queueSize': queueSize,
        'joinedAt':  joinedAt,
      },
    });

/// A canonical `match_found` event payload.
Map<String, dynamic> _matchFoundPayload({
  String matchId  = 'match-uuid-1',
  String roomCode = 'ABC123',
  String color    = 'red',
  Map<String, dynamic>? opponentOverrides,
}) =>
    {
      'matchId':  matchId,
      'roomCode': roomCode,
      'color':    color,
      'opponent': {
        'playerId': 'LUD-OPPO01',
        'fullName': 'Opponent Player',
        'avatar':   null,
        ...?opponentOverrides,
      },
    };

// ═════════════════════════════════════════════════════════════════════════════
// Tests
// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // Install the secure storage mock before every test so ApiClient can fetch
  // an access token without opening a platform channel.
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': _kValidAccessToken,
    });
  });

  // ── Models ──────────────────────────────────────────────────────────────────

  group('QueueStatus.fromJson', () {
    test('parses not-in-queue response', () {
      final qs = QueueStatus.fromJson({
        'inQueue':   false,
        'queueSize': 3,
        'joinedAt':  null,
      });
      expect(qs.inQueue,   isFalse);
      expect(qs.queueSize, equals(3));
      expect(qs.joinedAt,  isNull);
    });

    test('parses in-queue response with joinedAt', () {
      const ts = '2026-07-18T10:00:00.000Z';
      final qs = QueueStatus.fromJson({
        'inQueue':   true,
        'queueSize': 1,
        'joinedAt':  ts,
      });
      expect(qs.inQueue,   isTrue);
      expect(qs.queueSize, equals(1));
      expect(qs.joinedAt,  equals(ts));
    });
  });

  group('Opponent.fromJson', () {
    test('parses all fields', () {
      final op = Opponent.fromJson({
        'playerId': 'LUD-A1B2C3',
        'fullName': 'Test Player',
        'avatar':   'https://example.com/avatar.png',
      });
      expect(op.playerId, equals('LUD-A1B2C3'));
      expect(op.fullName, equals('Test Player'));
      expect(op.avatar,   equals('https://example.com/avatar.png'));
    });

    test('allows null avatar', () {
      final op = Opponent.fromJson({
        'playerId': 'LUD-A1B2C3',
        'fullName': 'Test Player',
        'avatar':   null,
      });
      expect(op.avatar, isNull);
    });
  });

  group('MatchFound.fromJson', () {
    test('parses full payload', () {
      final mf = MatchFound.fromJson(_matchFoundPayload());
      expect(mf.matchId,           equals('match-uuid-1'));
      expect(mf.roomCode,          equals('ABC123'));
      expect(mf.color,             equals('red'));
      expect(mf.opponent.playerId, equals('LUD-OPPO01'));
      expect(mf.opponent.fullName, equals('Opponent Player'));
      expect(mf.opponent.avatar,   isNull);
    });

    test('supports all valid colors', () {
      for (final color in ['red', 'blue', 'green', 'yellow']) {
        final mf = MatchFound.fromJson(_matchFoundPayload(color: color));
        expect(mf.color, equals(color));
      }
    });
  });

  // ── REST: getQueueStatus ───────────────────────────────────────────────────

  group('MatchmakingService.getQueueStatus', () {
    late _FakeSocketClient fakeSocket;

    setUp(() => fakeSocket = _FakeSocketClient());

    test('returns QueueStatus when not in queue', () async {
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async => http.Response(_queueStatusJson(), 200)),
        socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      final status = await svc.getQueueStatus();
      expect(status.inQueue,   isFalse);
      expect(status.queueSize, equals(0));
      expect(status.joinedAt,  isNull);
    });

    test('returns QueueStatus when in queue', () async {
      const ts = '2026-07-18T12:00:00.000Z';
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async =>
            http.Response(_queueStatusJson(inQueue: true, queueSize: 2, joinedAt: ts), 200)),
        socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      final status = await svc.getQueueStatus();
      expect(status.inQueue,   isTrue);
      expect(status.queueSize, equals(2));
      expect(status.joinedAt,  equals(ts));
    });

    test('throws SessionExpiredException on 401', () async {
      FlutterSecureStorage.setMockInitialValues({}); // no access token
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async =>
            http.Response(_json({'success': false, 'message': 'Unauthorized'}), 401)),
        socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await expectLater(svc.getQueueStatus(), throwsA(isA<SessionExpiredException>()));
    });

    test('throws MatchmakingException on 500', () async {
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async =>
            http.Response(_json({'message': 'Internal Server Error'}), 500)),
        socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await expectLater(svc.getQueueStatus(), throwsA(isA<MatchmakingException>()));
    });

    test('throws MatchmakingException on missing data field', () async {
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async =>
            http.Response(_json({'success': true}), 200)),
        socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await expectLater(svc.getQueueStatus(), throwsA(isA<MatchmakingException>()));
    });

    test('sends Authorization header with access token', () async {
      http.Request? captured;
      final svc = MatchmakingService(
        apiClient: _makeApiClient((req) async {
          captured = req;
          return http.Response(_queueStatusJson(), 200);
        }),
        socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.getQueueStatus();
      expect(captured?.headers['Authorization'],
          equals('Bearer $_kValidAccessToken'));
    });

    test('calls GET /match/queue/status endpoint', () async {
      http.Request? captured;
      final svc = MatchmakingService(
        apiClient: _makeApiClient((req) async {
          captured = req;
          return http.Response(_queueStatusJson(), 200);
        }),
        socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.getQueueStatus();
      expect(captured?.method, equals('GET'));
      expect(captured?.url.path, contains('/match/queue/status'));
    });
  });

  // ── Socket: joinQueue ──────────────────────────────────────────────────────

  group('MatchmakingService.joinQueue', () {
    late _FakeSocketClient fakeSocket;

    setUp(() => fakeSocket = _FakeSocketClient());

    ApiClient stubApiClient() =>
        _makeApiClient((_) async => http.Response(_queueStatusJson(), 200));

    test('calls connect on the socket client', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();
      expect(fakeSocket.connectCalled, isTrue);
    });

    test('emits find_match after connecting', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();
      expect(fakeSocket.emittedEvents, contains('find_match'));
    });

    test('find_match is the last emitted event', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();
      expect(fakeSocket.emittedEvents.last, equals('find_match'));
    });

    test('throws SessionExpiredException on unauthorized connect_error', () async {
      fakeSocket.configureConnectFailure('unauthorized');
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await expectLater(svc.joinQueue(), throwsA(isA<SessionExpiredException>()));
    });

    test('throws SessionExpiredException when token is absent', () async {
      fakeSocket.configureConnectFailure('No access token available.');
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await expectLater(svc.joinQueue(), throwsA(isA<SessionExpiredException>()));
    });

    test('throws MatchmakingException on generic connection failure', () async {
      fakeSocket.configureConnectFailure('Network unreachable');
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await expectLater(svc.joinQueue(), throwsA(isA<MatchmakingException>()));
    });

    test('calling joinQueue twice emits find_match each time', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();
      await svc.joinQueue();
      expect(
        fakeSocket.emittedEvents.where((e) => e == 'find_match').length,
        greaterThanOrEqualTo(2),
      );
    });
  });

  // ── Socket: leaveQueue ─────────────────────────────────────────────────────

  group('MatchmakingService.leaveQueue', () {
    late _FakeSocketClient fakeSocket;

    setUp(() => fakeSocket = _FakeSocketClient());

    ApiClient stubApiClient() =>
        _makeApiClient((_) async => http.Response(_queueStatusJson(), 200));

    test('emits leave_queue when connected', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();
      await svc.leaveQueue();

      expect(fakeSocket.emittedEvents, contains('leave_queue'));
    });

    test('disconnects socket after leaveQueue', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();
      await svc.leaveQueue();

      expect(fakeSocket.isConnected, isFalse);
    });

    test('does not throw when called without prior joinQueue', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await expectLater(svc.leaveQueue(), completes);
    });

    test('calling leaveQueue twice does not throw', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();
      await svc.leaveQueue();
      await expectLater(svc.leaveQueue(), completes);
    });
  });

  // ── Stream: onMatchFound ───────────────────────────────────────────────────

  group('MatchmakingService.onMatchFound', () {
    late _FakeSocketClient fakeSocket;

    setUp(() => fakeSocket = _FakeSocketClient());

    ApiClient stubApiClient() =>
        _makeApiClient((_) async => http.Response(_queueStatusJson(), 200));

    test('emits MatchFound when match_found socket event fires', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();

      final future = svc.onMatchFound.first;
      fakeSocket.simulateEvent('match_found', _matchFoundPayload());

      final event = await future.timeout(const Duration(seconds: 2));
      expect(event.matchId,           equals('match-uuid-1'));
      expect(event.roomCode,          equals('ABC123'));
      expect(event.color,             equals('red'));
      expect(event.opponent.playerId, equals('LUD-OPPO01'));
      expect(event.opponent.fullName, equals('Opponent Player'));
    });

    test('parses opponent avatar correctly', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();

      final future = svc.onMatchFound.first;
      fakeSocket.simulateEvent('match_found', _matchFoundPayload(
        opponentOverrides: {
          'playerId': 'LUD-X1Y2Z3',
          'fullName': 'Avatar Player',
          'avatar':   'https://cdn.example.com/avatar.png',
        },
      ));

      final event = await future.timeout(const Duration(seconds: 2));
      expect(event.opponent.avatar, equals('https://cdn.example.com/avatar.png'));
    });

    test('does not crash on malformed match_found payload', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();

      // Malformed events are silently dropped — no stream item should be emitted
      fakeSocket.simulateEvent('match_found', {'bad': 'data'});

      // Stream should not emit anything within a short window
      bool emitted = false;
      final sub = svc.onMatchFound.listen((_) => emitted = true);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted, isFalse);
    });

    test('stream emits multiple events across pairings', () async {
      final svc = MatchmakingService(
        apiClient: stubApiClient(), socketClient: fakeSocket,
      );
      addTearDown(svc.dispose);

      await svc.joinQueue();

      final events = <MatchFound>[];
      final sub = svc.onMatchFound.listen(events.add);
      addTearDown(sub.cancel);

      fakeSocket.simulateEvent(
          'match_found', _matchFoundPayload(matchId: 'm1', roomCode: 'AAA111'));
      fakeSocket.simulateEvent(
          'match_found', _matchFoundPayload(matchId: 'm2', roomCode: 'BBB222'));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events.length, equals(2));
      expect(events[0].matchId, equals('m1'));
      expect(events[1].matchId, equals('m2'));
    });
  });

  // ── Lifecycle: dispose ─────────────────────────────────────────────────────

  group('MatchmakingService.dispose', () {
    test('closes onMatchFound stream', () async {
      final fakeSocket = _FakeSocketClient();
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async => http.Response(_queueStatusJson(), 200)),
        socketClient: fakeSocket,
      );

      bool closed = false;
      svc.onMatchFound.listen((_) {}, onDone: () => closed = true);

      await svc.joinQueue();
      svc.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(closed, isTrue);
    });

    test('disconnects socket on dispose', () async {
      final fakeSocket = _FakeSocketClient();
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async => http.Response(_queueStatusJson(), 200)),
        socketClient: fakeSocket,
      );

      await svc.joinQueue();
      expect(fakeSocket.isConnected, isTrue);

      svc.dispose();
      expect(fakeSocket.isConnected, isFalse);
    });

    test('calling dispose twice does not throw', () {
      final svc = MatchmakingService(
        apiClient:    _makeApiClient((_) async => http.Response(_queueStatusJson(), 200)),
        socketClient: _FakeSocketClient(),
      );
      svc.dispose();
      expect(() => svc.dispose(), returnsNormally);
    });
  });
}
