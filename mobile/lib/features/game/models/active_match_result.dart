/// Result of GET /api/game/active-match.
///
/// [hasActiveMatch] is true when the authenticated player is currently
/// inside a running match, is not eliminated, and has lives remaining.
class ActiveMatchResult {
  const ActiveMatchResult({
    required this.hasActiveMatch,
    this.matchId,
    this.roomCode,
    this.playerColor,
    this.remainingLives,
  });

  final bool    hasActiveMatch;
  final String? matchId;
  final String? roomCode;
  final String? playerColor;
  final int?    remainingLives;

  factory ActiveMatchResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final has  = data['hasActiveMatch'] as bool;
    if (!has) return const ActiveMatchResult(hasActiveMatch: false);
    return ActiveMatchResult(
      hasActiveMatch: true,
      matchId:        data['matchId']        as String,
      roomCode:       data['roomCode']        as String,
      playerColor:    data['playerColor']     as String,
      remainingLives: data['remainingLives']  as int,
    );
  }
}
