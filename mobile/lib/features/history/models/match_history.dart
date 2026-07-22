import 'match_history_entry.dart';

/// Represents a paginated page of match history as returned by
/// GET /api/match/history.
///
/// [total] is the overall count of completed matches for the player
/// (i.e. `pagination.total` from the backend envelope), not the number
/// of entries in the current page.
class MatchHistory {
  const MatchHistory({
    required this.entries,
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// The matches included in this page, ordered newest first.
  final List<MatchHistoryEntry> entries;

  /// Total number of completed matches available across all pages.
  final int total;

  /// The limit that was applied to this page.
  final int limit;

  /// The offset that was applied to this page.
  final int offset;

  factory MatchHistory.fromJson(Map<String, dynamic> data) {
    final rawList  = data['matches']    as List<dynamic>;
    final pagination = data['pagination'] as Map<String, dynamic>;

    return MatchHistory(
      entries: rawList
          .map((e) => MatchHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      total:  pagination['total']  as int,
      limit:  pagination['limit']  as int,
      offset: pagination['offset'] as int,
    );
  }

  @override
  String toString() =>
      'MatchHistory(total: $total, limit: $limit, offset: $offset, '
      'entries: ${entries.length})';
}
