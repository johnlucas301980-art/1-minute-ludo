import 'dart:async';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../matchmaking/services/socket_client.dart';
import '../models/notification_item.dart';

/// Manages persisted notifications plus their authenticated realtime stream.
///
/// The REST API is the source of truth. Socket.IO supplies new rows and unread
/// count changes while the user is online; REST reconciliation runs on start
/// and after reconnects so missed events are recovered.
class NotificationService {
  NotificationService({
    required ApiClient apiClient,
    required SocketClient socketClient,
    FutureOr<void> Function()? onSessionExpired,
  })  : _api = apiClient,
        _socket = socketClient,
        _onSessionExpired = onSessionExpired;

  final ApiClient _api;
  final SocketClient _socket;
  final FutureOr<void> Function()? _onSessionExpired;

  final List<NotificationItem> _notifications = [];
  final StreamController<List<NotificationItem>> _notificationsController =
      StreamController<List<NotificationItem>>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  bool _started = false;
  bool _initializing = false;
  bool _recoveringSession = false;
  bool _disposed = false;
  int _unreadCount = 0;

  List<NotificationItem> get notifications =>
      List<NotificationItem>.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isRealtimeConnected => _socket.isConnected;

  Stream<List<NotificationItem>> get onNotificationsChanged =>
      _notificationsController.stream;
  Stream<int> get onUnreadCountChanged => _unreadCountController.stream;
  Stream<bool> get onRealtimeConnectionChanged => _connectionController.stream;
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  Future<void> start() async {
    if (_disposed || _started) return;
    _started = true;
    _initializing = true;

    _socket.on('notification_new', _handleNewNotification);
    _socket.on('notifications_unread_count', _handleUnreadCount);
    _socket.on('connect', _handleConnected);
    _socket.on('disconnect', _handleDisconnected);
    _socket.on('connect_error', _handleConnectError);

    try {
      await _socket.connect();
      _emitConnection(true);
      await _syncFromRest();
    } on SocketConnectionException catch (error) {
      await _recoverFromSocketError(error.message);
    } finally {
      _initializing = false;
    }
  }

  Future<void> refresh() => _syncFromRest();

  Future<void> markRead(String notificationId) async {
    try {
      final response = await _api.authenticatedRequest(
        'PUT',
        '/notifications/$notificationId/read',
      );
      final data = response['data'] as Map<String, dynamic>?;
      final json = data?['notification'];
      if (json is Map) {
        _upsert(NotificationItem.fromJson(_stringMap(json)));
      }
      await _syncFromRest();
    } on SessionExpiredException {
      await _expireSession();
    }
  }

  Future<void> markAllRead() async {
    try {
      final response = await _api.authenticatedRequest(
        'PUT',
        '/notifications/read-all',
      );
      final data = response['data'] as Map<String, dynamic>?;
      final unreadCount = data?['unread_count'];
      if (unreadCount is int) _setUnreadCount(unreadCount);

      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
      }
      _emitNotifications();
    } on SessionExpiredException {
      await _expireSession();
    }
  }

  Future<void> stop({bool clearState = true}) async {
    if (!_started) return;
    _started = false;
    _socket.off('notification_new');
    _socket.off('notifications_unread_count');
    _socket.off('connect');
    _socket.off('disconnect');
    _socket.off('connect_error');
    _socket.disconnect();
    _emitConnection(false);

    if (clearState) {
      _notifications.clear();
      _setUnreadCount(0);
      _emitNotifications();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
    _notificationsController.close();
    _unreadCountController.close();
    _connectionController.close();
    _sessionExpiredController.close();
  }

  Future<void> _syncFromRest() async {
    if (_disposed || !_started) return;

    try {
      final response = await _api.authenticatedRequest(
        'GET',
        '/notifications',
      );
      final data = response['data'] as Map<String, dynamic>?;
      final rawNotifications = data?['notifications'];
      if (rawNotifications is! List) {
        throw const FormatException('Notification response missing notifications.');
      }

      final fetched = <NotificationItem>[];
      for (final raw in rawNotifications) {
        if (raw is Map) {
          fetched.add(NotificationItem.fromJson(_stringMap(raw)));
        }
      }

      final merged = <String, NotificationItem>{
        for (final item in _notifications) item.id: item,
        for (final item in fetched) item.id: item,
      }.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _notifications
        ..clear()
        ..addAll(merged.take(100));
      _emitNotifications();

      final unreadCount = data?['unread_count'];
      if (unreadCount is int) _setUnreadCount(unreadCount);
    } on SessionExpiredException {
      await _expireSession();
    } on ApiException {
      // Temporary REST failures are recoverable on the next reconnect/refresh.
    } on FormatException {
      // Ignore malformed server data without terminating the realtime service.
    }
  }

  void _handleNewNotification(dynamic payload) {
    if (!_started || payload is! Map) return;
    try {
      final json = _stringMap(payload);
      final raw = json['notification'];
      if (raw is! Map) return;
      _upsert(NotificationItem.fromJson(_stringMap(raw)));
      final unreadCount = json['unread_count'];
      if (unreadCount is int) _setUnreadCount(unreadCount);
    } on FormatException {
      // A malformed event must not terminate the listener.
    }
  }

  void _handleUnreadCount(dynamic payload) {
    if (!_started || payload is! Map) return;
    final value = payload['unread_count'];
    if (value is int) _setUnreadCount(value);
  }

  void _handleConnected(dynamic _) {
    if (!_started) return;
    _emitConnection(true);
    if (!_initializing) unawaited(_syncFromRest());
  }

  void _handleDisconnected(dynamic _) {
    _emitConnection(false);
  }

  void _handleConnectError(dynamic error) {
    _emitConnection(false);
    if (!_started || _initializing || _recoveringSession) return;
    final message = error?.toString() ?? '';
    if (message.toLowerCase().contains('unauthorized')) {
      unawaited(_recoverFromSocketError(message));
    }
  }

  Future<void> _recoverFromSocketError(String message) async {
    if (_recoveringSession || !_started) return;
    _recoveringSession = true;
    try {
      // ApiClient performs its one silent refresh on this authenticated call.
      await _syncFromRest();
      if (_started && !_socket.isConnected) {
        await _socket.connect();
      }
    } on SocketConnectionException catch (error) {
      if (error.message.toLowerCase().contains('unauthorized')) {
        await _expireSession();
      }
    } finally {
      _recoveringSession = false;
    }
  }

  Future<void> _expireSession() async {
    if (!_started) return;
    await stop();
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
    await _onSessionExpired?.call();
  }

  void _upsert(NotificationItem item) {
    final index = _notifications.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      _notifications[index] = item;
    } else {
      _notifications.insert(0, item);
    }
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }
    _emitNotifications();
  }

  void _emitNotifications() {
    if (!_notificationsController.isClosed) {
      _notificationsController.add(notifications);
    }
  }

  void _setUnreadCount(int value) {
    _unreadCount = value < 0 ? 0 : value;
    if (!_unreadCountController.isClosed) {
      _unreadCountController.add(_unreadCount);
    }
  }

  void _emitConnection(bool connected) {
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
  }

  static Map<String, dynamic> _stringMap(Map<dynamic, dynamic> value) =>
      value.map((key, item) => MapEntry(key.toString(), item));
}