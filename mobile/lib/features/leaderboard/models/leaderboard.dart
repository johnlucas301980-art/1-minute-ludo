import 'leaderboard_entry.dart';

/// Represents the full leaderboard as returned by GET /api/leaderboard.
///
/// [entries] is the ordered list of players, ranked by wins descending
/// then full_name ascending. The list may be empty if no players exist.
class Leaderboard {
  const Leaderboard({required this.entries});

  /// The ranked list of players. Ordered by wins DESC, full_name ASC.
  final List<LeaderboardEntry> entries;

  /// Parses the value of `json['data']` from GET /api/leaderboard.
  factory Leaderboard.fromJson(Map<String, dynamic> data) {
    final rawList = data['leaderboard'] as List<dynamic>;
    return Leaderboard(
      entries: rawList
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() => 'Leaderboard(entries: ${entries.length})';
}
