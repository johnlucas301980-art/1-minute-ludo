import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/support/models/faq_item.dart';
import 'package:one_minute_ludo/features/support/models/support_ticket.dart';
import 'package:one_minute_ludo/features/support/services/support_service.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _faqJson({String? id}) => {
  'id':       id ?? 'faq-1',
  'category': 'Gameplay',
  'question': 'How long does a match last?',
  'answer':   'Exactly 60 seconds.',
};

Map<String, dynamic> _ticketJson({String? id, String status = 'open'}) => {
  'id':         id ?? 'ticket-uuid-1',
  'user_id':    'user-uuid-1',
  'subject':    'I cannot withdraw',
  'message':    'Every time I try to withdraw my points I get an error.',
  'status':     status,
  'created_at': '2026-07-24T10:00:00.000Z',
  'updated_at': '2026-07-24T10:00:00.000Z',
};

http.Response _faqsResponse({List<Map<String, dynamic>>? faqs}) =>
    _jsonResponse({
      'success': true,
      'data': {'faqs': faqs ?? [_faqJson()]},
    });

http.Response _ticketsResponse({List<Map<String, dynamic>>? tickets}) =>
    _jsonResponse({
      'success': true,
      'data': {
        'tickets': tickets ?? [_ticketJson()],
        'pagination': {'total': 1, 'limit': 20, 'offset': 0},
      },
    });

http.Response _ticketResponse({Map<String, dynamic>? ticket}) =>
    _jsonResponse({
      'success': true,
      'data': {'ticket': ticket ?? _ticketJson()},
    });

SupportService _buildService(http.Client httpClient) {
  FlutterSecureStorage.setMockInitialValues({
    'ludo_access_token': 'valid-access-token',
  });
  final tokenStorage = const TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage, httpClient: httpClient);
  return SupportService(apiClient: apiClient);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ── FaqItem.fromJson ────────────────────────────────────────────────────────

  group('FaqItem.fromJson', () {
    test('1 — parses all fields correctly', () {
      final item = FaqItem.fromJson(_faqJson());
      expect(item.id,       'faq-1');
      expect(item.category, 'Gameplay');
      expect(item.question, 'How long does a match last?');
      expect(item.answer,   'Exactly 60 seconds.');
    });

    test('2 — throws FormatException when id is missing', () {
      final json = _faqJson()..remove('id');
      expect(() => FaqItem.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('3 — throws FormatException when question is missing', () {
      final json = _faqJson()..remove('question');
      expect(() => FaqItem.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('4 — throws FormatException when answer is missing', () {
      final json = _faqJson()..remove('answer');
      expect(() => FaqItem.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('5 — equality: two FAQs with same data are equal', () {
      final a = FaqItem.fromJson(_faqJson());
      final b = FaqItem.fromJson(_faqJson());
      expect(a, equals(b));
    });

    test('6 — toString contains id and question', () {
      final item = FaqItem.fromJson(_faqJson());
      expect(item.toString(), contains('faq-1'));
      expect(item.toString(), contains('How long does a match last?'));
    });
  });

  // ── SupportTicket.fromJson ─────────────────────────────────────────────────

  group('SupportTicket.fromJson', () {
    test('7 — parses all fields correctly', () {
      final ticket = SupportTicket.fromJson(_ticketJson());
      expect(ticket.id,      'ticket-uuid-1');
      expect(ticket.userId,  'user-uuid-1');
      expect(ticket.subject, 'I cannot withdraw');
      expect(ticket.status,  'open');
      expect(ticket.createdAt, isA<DateTime>());
      expect(ticket.updatedAt, isA<DateTime>());
    });

    test('8 — throws FormatException when id is missing', () {
      final json = _ticketJson()..remove('id');
      expect(() => SupportTicket.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('9 — throws FormatException when subject is missing', () {
      final json = _ticketJson()..remove('subject');
      expect(() => SupportTicket.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('10 — throws FormatException when status is missing', () {
      final json = _ticketJson()..remove('status');
      expect(() => SupportTicket.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('11 — equality: two tickets with same data are equal', () {
      final a = SupportTicket.fromJson(_ticketJson());
      final b = SupportTicket.fromJson(_ticketJson());
      expect(a, equals(b));
    });

    test('12 — toString contains id and subject', () {
      final ticket = SupportTicket.fromJson(_ticketJson());
      expect(ticket.toString(), contains('ticket-uuid-1'));
      expect(ticket.toString(), contains('I cannot withdraw'));
    });
  });

  // ── SupportService.getFaqs ─────────────────────────────────────────────────

  group('SupportService.getFaqs', () {
    test('13 — returns a list of FaqItem on success', () async {
      final service = _buildService(MockClient((_) async => _faqsResponse()));
      final faqs = await service.getFaqs();
      expect(faqs, isA<List<FaqItem>>());
      expect(faqs.length, 1);
      expect(faqs.first.id, 'faq-1');
    });

    test('14 — returns multiple FAQs when server sends multiple', () async {
      final service = _buildService(MockClient((_) async => _faqsResponse(
        faqs: [_faqJson(id: 'faq-1'), _faqJson(id: 'faq-2')],
      )));
      final faqs = await service.getFaqs();
      expect(faqs.length, 2);
    });

    test('15 — returns empty list when server sends empty array', () async {
      final service = _buildService(MockClient((_) async => _faqsResponse(faqs: [])));
      final faqs = await service.getFaqs();
      expect(faqs, isEmpty);
    });

    test('16 — throws ApiException on 500', () async {
      final service = _buildService(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'Internal server error.'},
        status: 500,
      )));
      expect(() => service.getFaqs(), throwsException);
    });
  });

  // ── SupportService.submitTicket ────────────────────────────────────────────

  group('SupportService.submitTicket', () {
    test('17 — returns SupportTicket on success', () async {
      final service = _buildService(MockClient((_) async => _ticketResponse()));
      final ticket = await service.submitTicket(
        subject: 'I cannot withdraw',
        message: 'Every time I try to withdraw my points I get an error.',
      );
      expect(ticket, isA<SupportTicket>());
      expect(ticket.subject, 'I cannot withdraw');
      expect(ticket.status,  'open');
    });

    test('18 — sends subject and message in request body', () async {
      http.Request? capturedRequest;
      final service = _buildService(MockClient((request) async {
        capturedRequest = request;
        return _ticketResponse();
      }));

      await service.submitTicket(
        subject: 'My subject',
        message: 'My message is long enough.',
      );

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['subject'], 'My subject');
      expect(body['message'], 'My message is long enough.');
    });

    test('19 — uses POST method', () async {
      http.Request? capturedRequest;
      final service = _buildService(MockClient((request) async {
        capturedRequest = request;
        return _ticketResponse();
      }));

      await service.submitTicket(subject: 'Test', message: 'Test message long enough.');
      expect(capturedRequest!.method, 'POST');
    });

    test('20 — throws ApiException on 400 validation error', () async {
      final service = _buildService(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'subject must be at least 3 characters.'},
        status: 400,
      )));
      expect(
        () => service.submitTicket(subject: 'ab', message: 'Too short.'),
        throwsException,
      );
    });
  });

  // ── SupportService.getTickets ──────────────────────────────────────────────

  group('SupportService.getTickets', () {
    test('21 — returns a list of SupportTicket on success', () async {
      final service = _buildService(MockClient((_) async => _ticketsResponse()));
      final tickets = await service.getTickets();
      expect(tickets, isA<List<SupportTicket>>());
      expect(tickets.length, 1);
      expect(tickets.first.id, 'ticket-uuid-1');
    });

    test('22 — returns empty list when no tickets exist', () async {
      final service = _buildService(MockClient((_) async => _ticketsResponse(tickets: [])));
      final tickets = await service.getTickets();
      expect(tickets, isEmpty);
    });

    test('23 — passes limit and offset as query params', () async {
      http.Request? capturedRequest;
      final service = _buildService(MockClient((request) async {
        capturedRequest = request;
        return _ticketsResponse();
      }));

      await service.getTickets(limit: 5, offset: 10);
      expect(capturedRequest!.url.queryParameters['limit'],  '5');
      expect(capturedRequest!.url.queryParameters['offset'], '10');
    });

    test('24 — returns multiple tickets', () async {
      final service = _buildService(MockClient((_) async => _ticketsResponse(
        tickets: [_ticketJson(id: 't-1'), _ticketJson(id: 't-2')],
      )));
      final tickets = await service.getTickets();
      expect(tickets.length, 2);
    });
  });

  // ── SupportService.getTicketById ───────────────────────────────────────────

  group('SupportService.getTicketById', () {
    test('25 — returns SupportTicket when found', () async {
      final service = _buildService(MockClient((_) async => _ticketResponse()));
      final ticket = await service.getTicketById('ticket-uuid-1');
      expect(ticket, isNotNull);
      expect(ticket!.id, 'ticket-uuid-1');
    });

    test('26 — returns null on 404', () async {
      final service = _buildService(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'Ticket not found.'},
        status: 404,
      )));
      final ticket = await service.getTicketById('00000000-0000-4000-8000-000000000000');
      expect(ticket, isNull);
    });

    test('27 — rethrows non-404 ApiException', () async {
      final service = _buildService(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'Internal server error.'},
        status: 500,
      )));
      expect(
        () => service.getTicketById('ticket-uuid-1'),
        throwsException,
      );
    });
  });
}
