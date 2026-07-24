import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';
import 'package:one_minute_ludo/features/notifications/models/notification_item.dart';
import 'package:one_minute_ludo/features/notifications/services/notification_service.dart';

// ─── Fake SocketClient ─────────────────────────────────────────────────────

class _FakeSocketClient extends SocketClient {
  _FakeSocketClient() : super(tokenProvider: () async => 'fake-token');

  final Map<String, List<void Function(dynamic)>> _handlers = {};
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = true;
    final connectHandlers = List<void Function(dynamic)>.from(
      _handlers['connect'] ?? const [],
    );
    for (final fn in connectHandlers) {
      fn(null);
    }
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
    _handlers.clear();
  }

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

// ─── Helpers ───────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _notificationJson({String? id, bool isRead = false}) => {
  'id':           id ?? 'notif-uuid-1',
  'type':         'match_completed',
  'title':        'Match over',
  'message':      'You won!',
  'is_read':      isRead,
  'created_at':   '2026-07-23T10:00:00.000Z',
  'read_at':      isRead ? '2026-07-23T11:00:00.000Z' : null,
  'related_type': 'match',
  'related_id':   'match-uuid-1',
};

http.Response _listResponse({List<Map<String, dynamic>>? notifications}) {
  return _jsonResponse({
    'success': true,
    'data': {
      'notifications': notifications ?? [_notificationJson()],
      'unread_count':  notifications?.where((n) => n['is_read'] == false).length ?? 1,
      'pagination':    {'limit': 20, 'offset': 0, 'total': 1},
    },
  });
}

// ─── Tests ─────────────────────────────────────────────────────────────────

void main() {
  late _FakeSocketClient socket;
  late TokenStorage       tokenStorage;
  late NotificationService service;

  void buildService(http.Client httpClient) {
    tokenStorage = const TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage, httpClient: httpClient);
    service = NotificationService(apiClient: apiClient, socketClient: socket);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
    socket = _FakeSocketClient();
  });

  tearDown(() async {
    await service.stop();
    service.dispose();
  });

  // ── Streams exposed ───────────────────────────────────────────────────────

  test('1 — onNotificationsChanged stream is broadcast', () {
    buildService(MockClient((_) async => _listResponse()));
    expect(service.onNotificationsChanged, isA<Stream<List<NotificationItem>>>());
  });

  test('2 — onUnreadCountChanged stream is broadcast', () {
    buildService(MockClient((_) async => _listResponse()));
    expect(service.onUnreadCountChanged, isA<Stream<int>>());
  });

  test('3 — unreadCount starts at 0 before start()', () {
    buildService(MockClient((_) async => _listResponse()));
    expect(service.unreadCount, 0);
  });

  test('4 — notifications starts empty before start()', () {
    buildService(MockClient((_) async => _listResponse()));
    expect(service.notifications, isEmpty);
  });

  // ── REST reconciliation ───────────────────────────────────────────────────

  test('5 — start() fetches notifications from REST', () async {
    buildService(MockClient((_) async => _listResponse()));

    await service.start();
    await socket.connect();

    expect(service.notifications.length, 1);
    expect(service.notifications.first.id, 'notif-uuid-1');
  });

  test('6 — start() populates unreadCount from REST', () async {
    buildService(MockClient((_) async => _listResponse()));

    await service.start();
    await socket.connect();

    expect(service.unreadCount, 1);
  });

  test('7 — refresh() re-fetches and replaces notification list', () async {
    int callCount = 0;
    buildService(MockClient((_) async {
      callCount++;
      final id = callCount == 1 ? 'notif-uuid-1' : 'notif-uuid-2';
      return _listResponse(notifications: [_notificationJson(id: id)]);
    }));

    await service.start();
    await socket.connect();
    expect(service.notifications.first.id, 'notif-uuid-1');

    await service.refresh();
    expect(service.notifications.first.id, 'notif-uuid-2');
  });

  // ── Realtime: notification_new ────────────────────────────────────────────

  test('8 — notification_new socket event inserts new item', () async {
    buildService(MockClient((_) async => _listResponse(notifications: [])));

    await service.start();
    await socket.connect();
    expect(service.notifications, isEmpty);

    socket.simulateEvent('notification_new', {
      'notification': _notificationJson(id: 'realtime-uuid'),
      'unread_count': 1,
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.notifications.length, 1);
    expect(service.notifications.first.id, 'realtime-uuid');
  });

  test('9 — notification_new updates unreadCount from socket payload', () async {
    buildService(MockClient((_) async => _listResponse(notifications: [])));

    await service.start();
    await socket.connect();

    socket.simulateEvent('notification_new', {
      'notification': _notificationJson(id: 'realtime-uuid'),
      'unread_count': 3,
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.unreadCount, 3);
  });

  test('10 — duplicate notification_new with same id does not add duplicate', () async {
    buildService(MockClient((_) async => _listResponse(notifications: [])));

    await service.start();
    await socket.connect();

    final payload = {
      'notification': _notificationJson(id: 'realtime-uuid'),
      'unread_count': 1,
    };
    socket.simulateEvent('notification_new', payload);
    socket.simulateEvent('notification_new', payload);
    await Future<void>.delayed(Duration.zero);

    expect(service.notifications.where((n) => n.id == 'realtime-uuid').length, 1);
  });

  // ── Realtime: notifications_unread_count ──────────────────────────────────

  test('11 — notifications_unread_count socket event updates count', () async {
    buildService(MockClient((_) async => _listResponse()));

    await service.start();
    await socket.connect();

    socket.simulateEvent('notifications_unread_count', {'unread_count': 5});
    await Future<void>.delayed(Duration.zero);

    expect(service.unreadCount, 5);
  });

  test('12 — negative unread_count from socket is clamped to 0', () async {
    buildService(MockClient((_) async => _listResponse(notifications: [])));

    await service.start();
    await socket.connect();

    socket.simulateEvent('notifications_unread_count', {'unread_count': -3});
    await Future<void>.delayed(Duration.zero);

    expect(service.unreadCount, 0);
  });

  // ── Socket event registration ─────────────────────────────────────────────

  test('13 — notification_new handler is registered after start()', () async {
    buildService(MockClient((_) async => _listResponse()));

    await service.start();
    await socket.connect();

    expect(socket.hasHandler('notification_new'), isTrue);
  });

  test('14 — notifications_unread_count handler is registered after start()', () async {
    buildService(MockClient((_) async => _listResponse()));

    await service.start();
    await socket.connect();

    expect(socket.hasHandler('notifications_unread_count'), isTrue);
  });

  // ── stop() / dispose() ────────────────────────────────────────────────────

  test('15 — stop() resets notification list and unread count', () async {
    buildService(MockClient((_) async => _listResponse()));

    await service.start();
    await socket.connect();
    expect(service.notifications.length, 1);

    await service.stop();

    expect(service.notifications, isEmpty);
    expect(service.unreadCount,   0);
  });
}
