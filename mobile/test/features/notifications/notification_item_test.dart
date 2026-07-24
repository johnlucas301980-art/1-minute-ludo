import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/features/notifications/models/notification_item.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _minimalJson({Map<String, dynamic>? overrides}) => {
  'id':           'notif-uuid-1',
  'type':         'match_completed',
  'title':        'Match over',
  'message':      'You won!',
  'is_read':      false,
  'created_at':   '2026-07-23T10:00:00.000Z',
  'read_at':      null,
  'related_type': null,
  'related_id':   null,
  ...?overrides,
};

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('NotificationItem.fromJson', () {
    test('1 — parses all required fields from a complete payload', () {
      final item = NotificationItem.fromJson(_minimalJson());

      expect(item.id,      'notif-uuid-1');
      expect(item.type,    'match_completed');
      expect(item.title,   'Match over');
      expect(item.message, 'You won!');
      expect(item.isRead,  isFalse);
    });

    test('2 — createdAt is parsed as a DateTime', () {
      final item = NotificationItem.fromJson(_minimalJson());
      expect(item.createdAt, isA<DateTime>());
    });

    test('3 — readAt is null when server returns null', () {
      final item = NotificationItem.fromJson(_minimalJson());
      expect(item.readAt, isNull);
    });

    test('4 — readAt is parsed when server returns a timestamp', () {
      final item = NotificationItem.fromJson(_minimalJson(overrides: {
        'read_at': '2026-07-23T11:00:00.000Z',
      }));
      expect(item.readAt, isA<DateTime>());
    });

    test('5 — isRead is true when server sends true', () {
      final item = NotificationItem.fromJson(_minimalJson(overrides: {
        'is_read': true,
        'read_at': '2026-07-23T11:00:00.000Z',
      }));
      expect(item.isRead, isTrue);
    });

    test('6 — isRead is false for any non-true value', () {
      final item = NotificationItem.fromJson(_minimalJson(overrides: {
        'is_read': null,
      }));
      expect(item.isRead, isFalse);
    });

    test('7 — relatedType and relatedId are null when absent', () {
      final item = NotificationItem.fromJson(_minimalJson());
      expect(item.relatedType, isNull);
      expect(item.relatedId,   isNull);
    });

    test('8 — relatedType and relatedId are populated when present', () {
      final item = NotificationItem.fromJson(_minimalJson(overrides: {
        'related_type': 'match',
        'related_id':   'match-uuid-1',
      }));
      expect(item.relatedType, 'match');
      expect(item.relatedId,   'match-uuid-1');
    });

    test('9 — throws FormatException when id is missing', () {
      final json = _minimalJson()..remove('id');
      expect(() => NotificationItem.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('10 — throws FormatException when type is missing', () {
      final json = _minimalJson()..remove('type');
      expect(() => NotificationItem.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('11 — throws FormatException when title is missing', () {
      final json = _minimalJson()..remove('title');
      expect(() => NotificationItem.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('12 — throws FormatException when message is missing', () {
      final json = _minimalJson()..remove('message');
      expect(() => NotificationItem.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('13 — throws FormatException when created_at is missing', () {
      final json = _minimalJson()..remove('created_at');
      expect(() => NotificationItem.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('NotificationItem.copyWith', () {
    final original = NotificationItem.fromJson(_minimalJson());

    test('14 — copyWith(isRead: true) updates isRead', () {
      final updated = original.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.id,     original.id);
    });

    test('15 — copyWith(readAt: ...) updates readAt', () {
      final now = DateTime.now();
      final updated = original.copyWith(readAt: now);
      expect(updated.readAt, now);
    });

    test('16 — copyWith without arguments preserves all fields', () {
      final copy = original.copyWith();
      expect(copy.id,          original.id);
      expect(copy.type,        original.type);
      expect(copy.title,       original.title);
      expect(copy.message,     original.message);
      expect(copy.isRead,      original.isRead);
      expect(copy.relatedType, original.relatedType);
      expect(copy.relatedId,   original.relatedId);
      expect(copy.createdAt,   original.createdAt);
      expect(copy.readAt,      original.readAt);
    });
  });
}
