import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/history/services/history_service.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Canonical opponent JSON as returned by GET /api/match/history.
final _opponentJson = <String, dynamic>{
  'player_id': 'LUD-OPP123',
  'full_name': 'Opponent Player',
  'avatar':    null,
};

/// Canonical match entry JSON.
Map<String, dynamic> _entryJson({Map<String, dynamic>? overrides}) => {
  'match_id':      'match-uuid-1',
  'room_code':     'AB3Z9K',
  'mode':          'random',
  'started_at':    '2026-07-22T10:00:00.000Z',
  'finished_at':   '2026-07-22T10:01:00.000Z',
  'result':        'win',
  'earned_points': 10.0,
  'entry_points':  5.0,
  'opponent':      _opponentJson,
  ...?overrides,
};

/// Builds a full success response for GET /api/match/history.
http.Response _historyResponse({
  List<Map<String, dynamic>>? matches,
  int total  = 1,
  int limit  = 20,
  int offset = 0,
}) {
  final entries = matches ?? [_entryJson()];
  return _jsonResponse({
    'success': true,
    'data': {
      'matches': entries,
      'pagination': {
        'total':  total,
        'limit':  limit,
        'offset': offset,
      },
    },
  });
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage tokenStorage;
  late ApiClient apiClient;
  late HistoryService historyService;

  void buildServices(http.Client mockHttpClient) {
    tokenStorage   = const TokenStorage();
    apiClient      = ApiClient(tokenStorage: tokenStorage, httpClient: mockHttpClient);
    historyService = HistoryService(apiClient: apiClient);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ─── HistoryService.getHistory ────────────────────────────────────────────

  group('HistoryService.getHistory', () {
    test('1 — returns MatchHistory with all fields on success', () async {
      buildServices(MockClient((_) async => _historyResponse()));

      final history = await historyService.getHistory();

      expect(history.entries.length, 1);
      expect(history.total,          1);
      expect(history.limit,          20);
      expect(history.offset,         0);

      final entry = history.entries.first;
      expect(entry.matchId,      'match-uuid-1');
      expect(entry.roomCode,     'AB3Z9K');
      expect(entry.mode,         'random');
      expect(entry.result,       'win');
      expect(entry.earnedPoints, 10.0);
      expect(entry.entryPoints,  5.0);
    });

    test('2 — empty entries list when matches array is empty', () async {
      buildServices(MockClient((_) async => _historyResponse(matches: [], total: 0)));

      final history = await historyService.getHistory();

      expect(history.entries, isEmpty);
      expect(history.total,   0);
    });

    test('3 — result "win" preserved on entry', () async {
      buildServices(MockClient((_) async => _historyResponse(
        matches: [_entryJson(overrides: {'result': 'win'})],
      )));

      final history = await historyService.getHistory();
      expect(history.entries.first.result, 'win');
    });

    test('4 — result "loss" preserved on entry', () async {
      buildServices(MockClient((_) async => _historyResponse(
        matches: [_entryJson(overrides: {'result': 'loss'})],
      )));

      final history = await historyService.getHistory();
      expect(history.entries.first.result, 'loss');
    });

    test('5 — opponent fields mapped correctly', () async {
      final opponentWithAvatar = {
        ...(_opponentJson),
        'avatar': 'https://cdn.example.com/avatar.png',
      };
      buildServices(MockClient((_) async => _historyResponse(
        matches: [_entryJson(overrides: {'opponent': opponentWithAvatar})],
      )));

      final history  = await historyService.getHistory();
      final opponent = history.entries.first.opponent;

      expect(opponent.playerId, 'LUD-OPP123');
      expect(opponent.fullName, 'Opponent Player');
      expect(opponent.avatar,   'https://cdn.example.com/avatar.png');
    });

    test('6 — opponent avatar is null when absent', () async {
      buildServices(MockClient((_) async => _historyResponse()));

      final history  = await historyService.getHistory();
      expect(history.entries.first.opponent.avatar, isNull);
    });

    test('7 — earnedPoints and entryPoints parsed as double', () async {
      buildServices(MockClient((_) async => _historyResponse(
        matches: [_entryJson(overrides: {'earned_points': 10.5, 'entry_points': 2.5})],
      )));

      final entry = (await historyService.getHistory()).entries.first;
      expect(entry.earnedPoints, 10.5);
      expect(entry.entryPoints,  2.5);
    });

    test('8 — integer amounts from server coerced to double', () async {
      buildServices(MockClient((_) async => _historyResponse(
        matches: [_entryJson(overrides: {'earned_points': 10, 'entry_points': 5})],
      )));

      final entry = (await historyService.getHistory()).entries.first;
      expect(entry.earnedPoints, 10.0);
      expect(entry.entryPoints,  5.0);
    });

    test('9 — startedAt is null when server returns null', () async {
      buildServices(MockClient((_) async => _historyResponse(
        matches: [_entryJson(overrides: {'started_at': null})],
      )));

      final entry = (await historyService.getHistory()).entries.first;
      expect(entry.startedAt, isNull);
    });

    test('10 — finishedAt is null when server returns null', () async {
      buildServices(MockClient((_) async => _historyResponse(
        matches: [_entryJson(overrides: {'finished_at': null})],
      )));

      final entry = (await historyService.getHistory()).entries.first;
      expect(entry.finishedAt, isNull);
    });

    test('11 — default limit=20 used in request URL', () async {
      Uri? captured;
      buildServices(MockClient((req) async {
        captured = req.url;
        return _historyResponse();
      }));

      await historyService.getHistory();

      expect(captured, isNotNull);
      expect(captured!.queryParameters['limit'], '20');
    });

    test('12 — custom limit forwarded in request URL', () async {
      Uri? captured;
      buildServices(MockClient((req) async {
        captured = req.url;
        return _historyResponse(limit: 5);
      }));

      await historyService.getHistory(limit: 5);

      expect(captured!.queryParameters['limit'], '5');
    });

    test('13 — default offset=0 used in request URL', () async {
      Uri? captured;
      buildServices(MockClient((req) async {
        captured = req.url;
        return _historyResponse();
      }));

      await historyService.getHistory();

      expect(captured!.queryParameters['offset'], '0');
    });

    test('14 — custom offset forwarded in request URL', () async {
      Uri? captured;
      buildServices(MockClient((req) async {
        captured = req.url;
        return _historyResponse(offset: 40);
      }));

      await historyService.getHistory(offset: 40);

      expect(captured!.queryParameters['offset'], '40');
    });

    test('15 — pagination fields parsed from envelope', () async {
      buildServices(MockClient((_) async =>
          _historyResponse(total: 42, limit: 10, offset: 30)));

      final history = await historyService.getHistory(limit: 10, offset: 30);

      expect(history.total,  42);
      expect(history.limit,  10);
      expect(history.offset, 30);
    });

    test('16 — throws SessionExpiredException on 401 when refresh fails', () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token':  'expired-token',
        'ludo_refresh_token': 'expired-refresh-token',
      });

      buildServices(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'Token expired.'},
        status: 401,
      )));

      expect(
        () => historyService.getHistory(),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('17 — throws ApiException on 500', () async {
      buildServices(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'Internal server error.'},
        status: 500,
      )));

      expect(
        () => historyService.getHistory(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
