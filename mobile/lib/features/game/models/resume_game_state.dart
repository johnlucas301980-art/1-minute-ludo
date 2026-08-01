import '../../matchmaking/models/opponent.dart';

/// Payload of the `resume_game_state` Socket.IO event.
///
/// Emitted by the server in response to a `resume_game` emit from the client.
/// Contains the minimal data needed to open [GameScreen] directly when
/// resuming an in-progress match on app launch.
class ResumeGameState {
  const ResumeGameState({
    required this.matchId,
    required this.currentTurn,
    required this.opponent,
  });

  /// UUID of the in-progress match.
  final String matchId;

  /// Board colour of the player whose turn it currently is.
  /// One of: red, blue, green, yellow.
  final String currentTurn;

  /// The local player's opponent in this match.
  final Opponent opponent;

  factory ResumeGameState.fromJson(Map<String, dynamic> json) {
    final rawOpponent = json['opponent'];
    final opponentJson = rawOpponent is Map<dynamic, dynamic>
        ? rawOpponent.map((k, v) => MapEntry(k.toString(), v))
        : rawOpponent as Map<String, dynamic>?;

    return ResumeGameState(
      matchId:     json['matchId']     as String,
      currentTurn: json['currentTurn'] as String,
      opponent: opponentJson != null
          ? Opponent.fromJson(opponentJson)
          : const Opponent(playerId: '', fullName: 'Opponent', avatar: null),
    );
  }

  @override
  String toString() =>
      'ResumeGameState(matchId: $matchId, currentTurn: $currentTurn, '
      'opponent: $opponent)';
}
