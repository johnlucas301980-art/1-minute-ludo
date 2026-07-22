import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/features/history/models/match_history_entry.dart';
import 'package:one_minute_ludo/features/history/models/match_history.dart';

// ─── Canonical fixtures ───────────────────────────────────────────────────────

/// Canonical opponent JSON as returned within GET /api/match/history.
final _opponentJson = <String, dynamic>{
  'player_id': 'LUD-OPP123',
  'full_name': 'Opponent Player',
  'avatar':    null,
};

/// Canonical match entry JSON as returned within GET /api/match/history.
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

/// A full GET /api/match/history data envelope (the value of `json['data']`).
Map<String, dynamic> _historyData({
  List<Map<String, dynamic>>? matches,
  int total  = 1,
  int limit  = 20,
  int offset = 0,
}) {
  return {
    'matches': matches ?? [_entryJson()],
    'pagination': {
      'total':  total,
      'limit':  limit,
      'offset': offset,
    },
  };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── MatchOpponent.fromJson ───────────────────────────────────────────────

  group('MatchOpponent.fromJson', () {
    test('1 — all fields populated correctly', () {
      final json = <String, dynamic>{
        'player_id': 'LUD-OPP123',
        'full_name': 'Opponent Player',
        'avatar':    'https://cdn.example.com/avatar.png',
      };
      final opponent = MatchOpponent.fromJson(json);

      expect(opponent.playerId, 'LUD-OPP123');
      expect(opponent.fullName, 'Opponent Player');
      expect(opponent.avatar,   'https://cdn.example.com/avatar.png');
    });

    test('2 — avatar is null when server returns null', () {
      final opponent = MatchOpponent.fromJson(_opponentJson);

      expect(opponent.avatar, isNull);
    });

    test('3 — toString includes all fields', () {
      final opponent = MatchOpponent.fromJson(_opponentJson);
      final s = opponent.toString();

      expect(s, contains('LUD-OPP123'));
      expect(s, contains('Opponent Player'));
    });
  });

  // ─── MatchHistoryEntry.fromJson ───────────────────────────────────────────

  group('MatchHistoryEntry.fromJson', () {
    test('4 — all fields present and correctly typed', () {
      final entry = MatchHistoryEntry.fromJson(_entryJson());

      expect(entry.matchId,      'match-uuid-1');
      expect(entry.roomCode,     'AB3Z9K');
      expect(entry.mode,         'random');
      expect(entry.startedAt,    '2026-07-22T10:00:00.000Z');
      expect(entry.finishedAt,   '2026-07-22T10:01:00.000Z');
      expect(entry.result,       'win');
      expect(entry.earnedPoints, 10.0);
      expect(entry.entryPoints,  5.0);
      expect(entry.opponent.playerId, 'LUD-OPP123');
    });

    test('5 — result "loss" is preserved', () {
      final entry = MatchHistoryEntry.fromJson(_entryJson(overrides: {'result': 'loss'}));
      expect(entry.result, 'loss');
    });

    test('6 — startedAt is null when server returns null', () {
      final entry = MatchHistoryEntry.fromJson(
        _entryJson(overrides: {'started_at': null}),
      );
      expect(entry.startedAt, isNull);
    });

    test('7 — finishedAt is null when server returns null', () {
      final entry = MatchHistoryEntry.fromJson(
        _entryJson(overrides: {'finished_at': null}),
      );
      expect(entry.finishedAt, isNull);
    });

    test('8 — integer earned_points coerced to double', () {
      final entry = MatchHistoryEntry.fromJson(
        _entryJson(overrides: {'earned_points': 10, 'entry_points': 5}),
      );
      expect(entry.earnedPoints, 10.0);
      expect(entry.entryPoints,  5.0);
    });

    test('9 — zero points parsed as 0.0', () {
      final entry = MatchHistoryEntry.fromJson(
        _entryJson(overrides: {'earned_points': 0, 'entry_points': 0}),
      );
      expect(entry.earnedPoints, 0.0);
      expect(entry.entryPoints,  0.0);
    });

    test('10 — mode "friend" is preserved', () {
      final entry = MatchHistoryEntry.fromJson(
        _entryJson(overrides: {'mode': 'friend'}),
      );
      expect(entry.mode, 'friend');
    });

    test('11 — toString includes key fields', () {
      final entry = MatchHistoryEntry.fromJson(_entryJson());
      final s = entry.toString();

      expect(s, contains('match-uuid-1'));
      expect(s, contains('AB3Z9K'));
      expect(s, contains('win'));
    });
  });

  // ─── MatchHistory.fromJson ────────────────────────────────────────────────

  group('MatchHistory.fromJson', () {
    test('12 — single entry parsed correctly', () {
      final history = MatchHistory.fromJson(_historyData());

      expect(history.entries.length, 1);
      expect(history.entries.first.matchId, 'match-uuid-1');
    });

    test('13 — empty matches list produces empty entries', () {
      final history = MatchHistory.fromJson(
        _historyData(matches: [], total: 0),
      );

      expect(history.entries, isEmpty);
      expect(history.total,   0);
    });

    test('14 — pagination fields parsed from envelope', () {
      final history = MatchHistory.fromJson(
        _historyData(total: 42, limit: 10, offset: 20),
      );

      expect(history.total,  42);
      expect(history.limit,  10);
      expect(history.offset, 20);
    });

    test('15 — multiple entries produce correct length', () {
      final history = MatchHistory.fromJson(
        _historyData(
          matches: [_entryJson(), _entryJson(overrides: {'match_id': 'match-uuid-2'})],
          total: 2,
        ),
      );

      expect(history.entries.length, 2);
      expect(history.entries[1].matchId, 'match-uuid-2');
    });

    test('16 — toString includes entry count and pagination', () {
      final history = MatchHistory.fromJson(_historyData(total: 42));
      final s = history.toString();

      expect(s, contains('total: 42'));
      expect(s, contains('entries: 1'));
    });
  });
}
