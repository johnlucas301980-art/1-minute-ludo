import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/leaderboard/services/leaderboard_service.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Canonical entry JSON as returned within GET /api/leaderboard.
Map<String, dynamic> _entryJson({Map<String, dynamic>? overrides}) => {
  'rank':      1,
  'player_id': 'LUD-ABC123',
  'full_name': 'Alice Smith',
  'avatar':    null,
  'wins':      5,
  ...?overrides,
};

/// Builds a full success response for GET /api/leaderboard.
http.Response _leaderboardResponse({
  List<Map<String, dynamic>>? entries,
}) {
  return _jsonResponse({
    'success': true,
    'data': {
      'leaderboard': entries ?? [_entryJson()],
    },
  });
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late TokenStorage       tokenStorage;
  late ApiClient          apiClient;
  late LeaderboardService leaderboardService;

  void buildServices(http.Client mockHttpClient) {
    tokenStorage       = const TokenStorage();
    apiClient          = ApiClient(tokenStorage: tokenStorage, httpClient: mockHttpClient);
    leaderboardService = LeaderboardService(apiClient: apiClient);
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'ludo_access_token': 'valid-access-token',
    });
  });

  // ─── LeaderboardService.getLeaderboard ────────────────────────────────────

  group('LeaderboardService.getLeaderboard', () {
    test('1 — returns Leaderboard with all entry fields on success', () async {
      buildServices(MockClient((_) async => _leaderboardResponse()));

      final board = await leaderboardService.getLeaderboard();

      expect(board.entries.length,         1);
      expect(board.entries.first.rank,     1);
      expect(board.entries.first.playerId, 'LUD-ABC123');
      expect(board.entries.first.fullName, 'Alice Smith');
      expect(board.entries.first.avatar,   isNull);
      expect(board.entries.first.wins,     5);
    });

    test('2 — returns Leaderboard with empty entries when array is empty',
        () async {
      buildServices(MockClient((_) async => _leaderboardResponse(entries: [])));

      final board = await leaderboardService.getLeaderboard();

      expect(board.entries, isEmpty);
    });

    test('3 — avatar null preserved on entry', () async {
      buildServices(MockClient((_) async => _leaderboardResponse(entries: [
        _entryJson(overrides: {'avatar': null}),
      ])));

      final board = await leaderboardService.getLeaderboard();

      expect(board.entries.first.avatar, isNull);
    });

    test('4 — avatar URL preserved on entry', () async {
      buildServices(MockClient((_) async => _leaderboardResponse(entries: [
        _entryJson(overrides: {'avatar': 'https://cdn.example.com/pic.jpg'}),
      ])));

      final board = await leaderboardService.getLeaderboard();

      expect(board.entries.first.avatar, 'https://cdn.example.com/pic.jpg');
    });

    test('5 — request URL contains /leaderboard', () async {
      Uri? captured;
      buildServices(MockClient((req) async {
        captured = req.url;
        return _leaderboardResponse();
      }));

      await leaderboardService.getLeaderboard();

      expect(captured, isNotNull);
      expect(captured!.path, contains('/leaderboard'));
    });

    test('6 — throws SessionExpiredException on 401 when refresh fails',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'ludo_access_token':  'expired-token',
        'ludo_refresh_token': 'expired-refresh-token',
      });

      buildServices(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'Token expired.'},
        status: 401,
      )));

      expect(
        () => leaderboardService.getLeaderboard(),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('7 — throws ApiException on 500', () async {
      buildServices(MockClient((_) async => _jsonResponse(
        {'success': false, 'message': 'Internal server error.'},
        status: 500,
      )));

      expect(
        () => leaderboardService.getLeaderboard(),
        throwsA(isA<ApiException>()),
      );
    });

    test('8 — multiple entries parsed with correct ranks', () async {
      buildServices(MockClient((_) async => _leaderboardResponse(entries: [
        _entryJson(overrides: {'rank': 1, 'player_id': 'LUD-AAA', 'wins': 10}),
        _entryJson(overrides: {'rank': 2, 'player_id': 'LUD-BBB', 'wins': 7}),
      ])));

      final board = await leaderboardService.getLeaderboard();

      expect(board.entries.length,        2);
      expect(board.entries[0].rank,       1);
      expect(board.entries[0].playerId,   'LUD-AAA');
      expect(board.entries[1].rank,       2);
      expect(board.entries[1].playerId,   'LUD-BBB');
    });
  });
}
