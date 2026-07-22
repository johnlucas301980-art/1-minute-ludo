/// Represents a single player's entry in the global leaderboard,
/// as returned by GET /api/leaderboard.
///
/// JSON keys are snake_case (REST convention).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.fullName,
    this.avatar,
    required this.wins,
  });

  /// Sequential position on the leaderboard (1-based).
  final int rank;

  /// The player's public identifier (e.g. "LUD-A1B2C3").
  final String playerId;

  /// The player's display name.
  final String fullName;

  /// URL of the player's avatar image, or null when not set.
  final String? avatar;

  /// Number of finished matches won by this player.
  final int wins;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank:     (json['rank']     as num).toInt(),
      playerId: json['player_id'] as String,
      fullName: json['full_name'] as String,
      avatar:   json['avatar']   as String?,
      wins:     (json['wins']     as num).toInt(),
    );
  }

  @override
  String toString() =>
      'LeaderboardEntry(rank: $rank, playerId: $playerId, '
      'fullName: $fullName, avatar: $avatar, wins: $wins)';
}
