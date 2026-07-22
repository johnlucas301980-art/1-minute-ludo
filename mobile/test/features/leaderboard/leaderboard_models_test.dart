import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/features/leaderboard/models/leaderboard_entry.dart';
import 'package:one_minute_ludo/features/leaderboard/models/leaderboard.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

/// Canonical entry JSON as returned within GET /api/leaderboard.
Map<String, dynamic> _entryJson({Map<String, dynamic>? overrides}) => {
  'rank':      1,
  'player_id': 'LUD-ABC123',
  'full_name': 'Alice Smith',
  'avatar':    null,
  'wins':      5,
  ...?overrides,
};

/// A full GET /api/leaderboard data envelope (the value of `json['data']`).
Map<String, dynamic> _leaderboardData({
  List<Map<String, dynamic>>? entries,
}) {
  return {
    'leaderboard': entries ?? [_entryJson()],
  };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── LeaderboardEntry.fromJson ────────────────────────────────────────────

  group('LeaderboardEntry.fromJson', () {
    test('1 — all fields populated correctly', () {
      final entry = LeaderboardEntry.fromJson(_entryJson(overrides: {
        'avatar': 'https://cdn.example.com/avatar.png',
      }));

      expect(entry.rank,     1);
      expect(entry.playerId, 'LUD-ABC123');
      expect(entry.fullName, 'Alice Smith');
      expect(entry.avatar,   'https://cdn.example.com/avatar.png');
      expect(entry.wins,     5);
    });

    test('2 — avatar is null when server returns null', () {
      final entry = LeaderboardEntry.fromJson(_entryJson());

      expect(entry.avatar, isNull);
    });

    test('3 — avatar URL preserved when present', () {
      final entry = LeaderboardEntry.fromJson(_entryJson(overrides: {
        'avatar': 'https://example.com/pic.jpg',
      }));

      expect(entry.avatar, 'https://example.com/pic.jpg');
    });

    test('4 — rank coerced to int from num', () {
      // PostgreSQL ROW_NUMBER() may arrive as a num; toInt() must be applied.
      final entry = LeaderboardEntry.fromJson(_entryJson(overrides: {
        'rank': 3,
      }));

      expect(entry.rank, isA<int>());
      expect(entry.rank, 3);
    });

    test('5 — wins coerced to int from num', () {
      final entry = LeaderboardEntry.fromJson(_entryJson(overrides: {
        'wins': 12,
      }));

      expect(entry.wins, isA<int>());
      expect(entry.wins, 12);
    });

    test('6 — zero wins parsed as 0', () {
      final entry = LeaderboardEntry.fromJson(_entryJson(overrides: {
        'wins': 0,
      }));

      expect(entry.wins, 0);
    });

    test('7 — toString contains playerId and fullName', () {
      final entry = LeaderboardEntry.fromJson(_entryJson());
      final s     = entry.toString();

      expect(s, contains('LUD-ABC123'));
      expect(s, contains('Alice Smith'));
    });
  });

  // ─── Leaderboard.fromJson ─────────────────────────────────────────────────

  group('Leaderboard.fromJson', () {
    test('8 — single entry parsed — correct length and fields', () {
      final board = Leaderboard.fromJson(_leaderboardData());

      expect(board.entries.length,         1);
      expect(board.entries.first.playerId, 'LUD-ABC123');
      expect(board.entries.first.rank,     1);
    });

    test('9 — empty leaderboard array produces empty entries', () {
      final board = Leaderboard.fromJson(_leaderboardData(entries: []));

      expect(board.entries, isEmpty);
    });

    test('10 — multiple entries produce correct length', () {
      final board = Leaderboard.fromJson(_leaderboardData(entries: [
        _entryJson(overrides: {'rank': 1, 'player_id': 'LUD-AAA', 'wins': 10}),
        _entryJson(overrides: {'rank': 2, 'player_id': 'LUD-BBB', 'wins': 7}),
        _entryJson(overrides: {'rank': 3, 'player_id': 'LUD-CCC', 'wins': 3}),
      ]));

      expect(board.entries.length, 3);
    });

    test('11 — second entry fields parsed correctly', () {
      final board = Leaderboard.fromJson(_leaderboardData(entries: [
        _entryJson(overrides: {'rank': 1, 'player_id': 'LUD-AAA', 'wins': 10}),
        _entryJson(overrides: {
          'rank':      2,
          'player_id': 'LUD-BBB',
          'full_name': 'Bob Jones',
          'wins':      7,
        }),
      ]));

      final second = board.entries[1];
      expect(second.rank,     2);
      expect(second.playerId, 'LUD-BBB');
      expect(second.fullName, 'Bob Jones');
      expect(second.wins,     7);
    });

    test('12 — toString includes entry count', () {
      final board = Leaderboard.fromJson(_leaderboardData());
      final s     = board.toString();

      expect(s, contains('entries: 1'));
    });
  });
}
