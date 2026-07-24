import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/notifications/models/notification_item.dart';
import 'package:one_minute_ludo/features/notifications/screens/notification_center_screen.dart';
import 'package:one_minute_ludo/features/notifications/services/notification_service.dart';

// ─── Fake NotificationService ────────────────────────────────────────────────

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({
    List<NotificationItem>? initialNotifications,
    int initialUnreadCount = 0,
  })  : _notifications = initialNotifications ?? [],
        _unreadCount   = initialUnreadCount;

  List<NotificationItem> _notifications;
  int _unreadCount;

  final _notificationsController = StreamController<List<NotificationItem>>.broadcast();
  final _unreadCountController    = StreamController<int>.broadcast();

  bool refreshCalled    = false;
  bool markAllCalled    = false;
  final List<String> markedReadIds = [];

  @override
  List<NotificationItem> get notifications => _notifications;

  @override
  int get unreadCount => _unreadCount;

  @override
  Stream<List<NotificationItem>> get onNotificationsChanged =>
      _notificationsController.stream;

  @override
  Stream<int> get onUnreadCountChanged => _unreadCountController.stream;

  // Unused streams — return empty
  @override
  Stream<bool> get onConnectionChanged => const Stream.empty();

  @override
  Stream<void> get onSessionExpired => const Stream.empty();

  @override
  Future<void> refresh() async {
    refreshCalled = true;
  }

  @override
  Future<void> markRead(String notificationId) async {
    markedReadIds.add(notificationId);
    _notifications = _notifications.map((n) {
      if (n.id == notificationId) return n.copyWith(isRead: true);
      return n;
    }).toList();
    _unreadCount   = _notifications.where((n) => !n.isRead).length;
    _notificationsController.add(_notifications);
    _unreadCountController.add(_unreadCount);
  }

  @override
  Future<void> markAllRead() async {
    markAllCalled  = true;
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount   = 0;
    _notificationsController.add(_notifications);
    _unreadCountController.add(0);
  }

  // ── Lifecycle stubs ──────────────────────────────────────────────────────
  @override Future<void> start({VoidCallback? onSessionExpired}) async {}
  @override Future<void> stop() async {}
  @override void dispose() {
    _notificationsController.close();
    _unreadCountController.close();
  }

  void pushNotifications(List<NotificationItem> items) {
    _notifications = items;
    _notificationsController.add(items);
  }

  void pushUnreadCount(int count) {
    _unreadCount = count;
    _unreadCountController.add(count);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

NotificationItem _notification({
  required String id,
  required String title,
  required bool isRead,
}) {
  return NotificationItem(
    id:          id,
    type:        'match_completed',
    title:       title,
    message:     'Test message.',
    relatedType: null,
    relatedId:   null,
    isRead:      isRead,
    createdAt:   DateTime(2026, 7, 23, 10),
    readAt:      isRead ? DateTime(2026, 7, 23, 11) : null,
  );
}

Widget _buildScreen(_FakeNotificationService service) {
  return MaterialApp(
    home: NotificationCenterScreen(notificationService: service),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('NotificationCenterScreen', () {
    testWidgets('1 — shows empty-state text when there are no notifications',
        (tester) async {
      final service = _FakeNotificationService();
      await tester.pumpWidget(_buildScreen(service));

      expect(find.text('You have no notifications.'), findsOneWidget);
    });

    testWidgets('2 — renders a tile for each notification', (tester) async {
      final service = _FakeNotificationService(
        initialNotifications: [
          _notification(id: 'n1', title: 'Win!',  isRead: false),
          _notification(id: 'n2', title: 'Loss!', isRead: true),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));

      expect(find.text('Win!'),  findsOneWidget);
      expect(find.text('Loss!'), findsOneWidget);
    });

    testWidgets('3 — calls refresh() on init', (tester) async {
      final service = _FakeNotificationService();
      await tester.pumpWidget(_buildScreen(service));

      expect(service.refreshCalled, isTrue);
    });

    testWidgets('4 — "Mark all read" button is disabled when unreadCount is 0',
        (tester) async {
      final service = _FakeNotificationService(initialUnreadCount: 0);
      await tester.pumpWidget(_buildScreen(service));

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Mark all read'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('5 — "Mark all read" button is enabled when there are unread items',
        (tester) async {
      final service = _FakeNotificationService(initialUnreadCount: 2);
      await tester.pumpWidget(_buildScreen(service));

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Mark all read'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('6 — tapping "Mark all read" calls markAllRead()', (tester) async {
      final service = _FakeNotificationService(
        initialUnreadCount: 1,
        initialNotifications: [
          _notification(id: 'n1', title: 'Win!', isRead: false),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));

      await tester.tap(find.widgetWithText(TextButton, 'Mark all read'));
      await tester.pump();

      expect(service.markAllCalled, isTrue);
    });

    testWidgets('7 — tapping an unread tile calls markRead() with its id',
        (tester) async {
      final service = _FakeNotificationService(
        initialNotifications: [
          _notification(id: 'n1', title: 'Win!', isRead: false),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));

      await tester.tap(find.text('Win!'));
      await tester.pump();

      expect(service.markedReadIds, contains('n1'));
    });

    testWidgets('8 — tapping a read tile does nothing', (tester) async {
      final service = _FakeNotificationService(
        initialNotifications: [
          _notification(id: 'n1', title: 'Read one', isRead: true),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));

      await tester.tap(find.text('Read one'));
      await tester.pump();

      expect(service.markedReadIds, isEmpty);
    });

    testWidgets(
        '9 — list updates when onNotificationsChanged emits new items',
        (tester) async {
      final service = _FakeNotificationService();
      await tester.pumpWidget(_buildScreen(service));
      expect(find.text('You have no notifications.'), findsOneWidget);

      service.pushNotifications([
        _notification(id: 'n1', title: 'Late arrival', isRead: false),
      ]);
      await tester.pump();

      expect(find.text('Late arrival'), findsOneWidget);
      expect(find.text('You have no notifications.'), findsNothing);
    });

    testWidgets(
        '10 — "Mark all read" becomes disabled when onUnreadCountChanged emits 0',
        (tester) async {
      final service = _FakeNotificationService(initialUnreadCount: 2);
      await tester.pumpWidget(_buildScreen(service));

      service.pushUnreadCount(0);
      await tester.pump();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Mark all read'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('11 — "Notifications" title is visible in AppBar',
        (tester) async {
      final service = _FakeNotificationService();
      await tester.pumpWidget(_buildScreen(service));

      expect(find.text('Notifications'), findsOneWidget);
    });
  });
}
