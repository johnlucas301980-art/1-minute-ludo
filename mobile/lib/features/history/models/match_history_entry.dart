/// Represents the opponent in a completed match, as returned within
/// GET /api/match/history.
///
/// JSON keys are snake_case (REST convention), distinct from the camelCase
/// keys used in Socket.IO event payloads.
class MatchOpponent {
  const MatchOpponent({
    required this.playerId,
    required this.fullName,
    this.avatar,
  });

  /// The opponent's public player ID (e.g. "LUD-A1B2C3").
  final String playerId;

  /// The opponent's display name.
  final String fullName;

  /// URL of the opponent's avatar image, or null when not set.
  final String? avatar;

  factory MatchOpponent.fromJson(Map<String, dynamic> json) {
    return MatchOpponent(
      playerId: json['player_id'] as String,
      fullName: json['full_name'] as String,
      avatar:   json['avatar']   as String?,
    );
  }

  @override
  String toString() =>
      'MatchOpponent(playerId: $playerId, fullName: $fullName, avatar: $avatar)';
}

/// Represents a single completed match in the player's match history,
/// as returned by GET /api/match/history.
class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.matchId,
    required this.roomCode,
    required this.mode,
    this.startedAt,
    this.finishedAt,
    required this.result,
    required this.earnedPoints,
    required this.entryPoints,
    required this.opponent,
  });

  /// UUID of the match row.
  final String matchId;

  /// 6-character alphanumeric room code (e.g. "AB3Z9K").
  final String roomCode;

  /// Match mode — one of: random, friend.
  final String mode;

  /// ISO-8601 timestamp of when the match started, or null if unavailable.
  final String? startedAt;

  /// ISO-8601 timestamp of when the match finished, or null if unavailable.
  final String? finishedAt;

  /// Outcome for the requesting player — either "win" or "loss".
  final String result;

  /// Points earned by the requesting player in this match.
  final double earnedPoints;

  /// Entry fee (points) required to join this match.
  final double entryPoints;

  /// The opposing player's display info.
  final MatchOpponent opponent;

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryEntry(
      matchId:      json['match_id']      as String,
      roomCode:     json['room_code']     as String,
      mode:         json['mode']          as String,
      startedAt:    json['started_at']    as String?,
      finishedAt:   json['finished_at']   as String?,
      result:       json['result']        as String,
      earnedPoints: (json['earned_points'] as num).toDouble(),
      entryPoints:  (json['entry_points']  as num).toDouble(),
      opponent:     MatchOpponent.fromJson(
                      json['opponent'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() =>
      'MatchHistoryEntry(matchId: $matchId, roomCode: $roomCode, '
      'mode: $mode, result: $result, earnedPoints: $earnedPoints, '
      'entryPoints: $entryPoints, opponent: $opponent)';
}
