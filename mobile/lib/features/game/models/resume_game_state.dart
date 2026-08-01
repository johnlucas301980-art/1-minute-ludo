import '../../matchmaking/models/opponent.dart';

// ─── PawnPosition ─────────────────────────────────────────────────────────────

/// Position of a single pawn, as stored in the backend [LudoGameState].
///
/// Position encoding (colour-relative):
///   0      = yard (home base, not yet on the board)
///   1–51   = shared track
///   52–56  = home column (colour-specific; cannot be captured)
///   57     = finished (in the centre)
class PawnPosition {
  const PawnPosition({required this.position});

  final int position;

  factory PawnPosition.fromJson(Map<String, dynamic> json) {
    return PawnPosition(position: json['position'] as int);
  }

  @override
  String toString() => 'PawnPosition(position: $position)';
}

// ─── ResumeValidMove ──────────────────────────────────────────────────────────

/// A legal pawn move included in `resume_game_state` when
/// [ResumeGameState.phase] is `waiting_move`.
///
/// Mirrors the backend `ValidMove` type from `game_engine.ts`.
class ResumeValidMove {
  const ResumeValidMove({
    required this.pawnIndex,
    required this.fromPos,
    required this.toPos,
  });

  /// Index of the pawn that can move (0–3).
  final int pawnIndex;

  /// Current colour-relative position of the pawn.
  final int fromPos;

  /// Position the pawn would reach after the move.
  final int toPos;

  factory ResumeValidMove.fromJson(Map<String, dynamic> json) {
    return ResumeValidMove(
      pawnIndex: json['pawnIndex'] as int,
      fromPos:   json['fromPos']   as int,
      toPos:     json['toPos']     as int,
    );
  }

  @override
  String toString() =>
      'ResumeValidMove(pawnIndex: $pawnIndex, fromPos: $fromPos, toPos: $toPos)';
}

// ─── ResumePlayerState ────────────────────────────────────────────────────────

/// Snapshot of one player's in-memory state, as stored in the backend
/// [PlayerState] type from `game_engine.ts`.
class ResumePlayerState {
  const ResumePlayerState({
    required this.userId,
    required this.color,
    required this.pawns,
    required this.lives,
    required this.eliminated,
  });

  /// The player's UUID (matches `users.id` in the database).
  final String userId;

  /// Board colour assigned to this player.
  /// One of: red, blue, green, yellow.
  final String color;

  /// Positions of all 4 pawns, in index order (0–3).
  final List<PawnPosition> pawns;

  /// Remaining lives (starts at 5; decremented on turn timeout).
  final int lives;

  /// True when lives have reached 0; eliminated players are skipped on turns.
  final bool eliminated;

  factory ResumePlayerState.fromJson(Map<String, dynamic> json) {
    final rawPawns = json['pawns'] as List<dynamic>;
    return ResumePlayerState(
      userId:     json['userId']     as String,
      color:      json['color']      as String,
      pawns:      rawPawns.map((p) {
        final pawnMap = (p as Map<dynamic, dynamic>)
            .map((k, v) => MapEntry(k.toString(), v));
        return PawnPosition.fromJson(pawnMap);
      }).toList(),
      lives:      json['lives']      as int,
      eliminated: json['eliminated'] as bool,
    );
  }

  @override
  String toString() =>
      'ResumePlayerState(userId: $userId, color: $color, lives: $lives, '
      'eliminated: $eliminated, pawns: $pawns)';
}

// ─── ResumeGameState ──────────────────────────────────────────────────────────

/// Payload of the `resume_game_state` Socket.IO event.
///
/// Emitted by the server in response to a `resume_game { matchId }` emit.
/// Contains the full in-memory [LudoGameState] (from `game_engine.ts`) plus
/// the `roomCode` and opponent profile needed to reconstruct [MatchFound].
///
/// Field mapping from the backend:
/// ```
/// resume_game_state {
///   matchId     : string          — matches.id
///   roomCode    : string          — matches.room_code
///   currentTurn : PawnColor       — LudoGameState.currentTurn
///   phase       : GamePhase       — 'waiting_roll' | 'waiting_move'
///   diceValue   : number | null   — LudoGameState.diceValue
///   validMoves  : ValidMove[]     — LudoGameState.validMoves
///   players     : PlayerState[]   — LudoGameState.players (always 2)
///   opponent    : { playerId, fullName, avatar }
/// }
/// ```
class ResumeGameState {
  const ResumeGameState({
    required this.matchId,
    required this.roomCode,
    required this.currentTurn,
    required this.phase,
    required this.diceValue,
    required this.validMoves,
    required this.players,
    required this.opponent,
  });

  /// UUID of the in-progress match.
  final String matchId;

  /// 6-character alphanumeric room code (e.g. "AB3Z9K").
  final String roomCode;

  /// Board colour of the player whose turn it currently is.
  /// One of: red, blue, green, yellow.
  final String currentTurn;

  /// Current turn phase.
  ///   `waiting_roll` — the active player must roll the dice.
  ///   `waiting_move` — the active player has rolled and must move a pawn.
  final String phase;

  /// Dice value from the most recent roll; null when [phase] is `waiting_roll`.
  final int? diceValue;

  /// Legal pawn moves available to the active player.
  /// Non-empty only when [phase] is `waiting_move`.
  final List<ResumeValidMove> validMoves;

  /// Snapshots of both players' pawn positions, lives, and elimination state.
  /// Always contains exactly 2 entries.
  final List<ResumePlayerState> players;

  /// The local player's opponent.
  final Opponent opponent;

  factory ResumeGameState.fromJson(Map<String, dynamic> json) {
    final rawPlayers    = json['players']    as List<dynamic>;
    final rawValidMoves = json['validMoves'] as List<dynamic>;

    final rawOpponent = json['opponent'];
    final Map<String, dynamic> opponentMap;
    if (rawOpponent is Map<dynamic, dynamic>) {
      opponentMap = rawOpponent.map((k, v) => MapEntry(k.toString(), v));
    } else {
      opponentMap = rawOpponent as Map<String, dynamic>;
    }

    return ResumeGameState(
      matchId:     json['matchId']     as String,
      roomCode:    json['roomCode']    as String,
      currentTurn: json['currentTurn'] as String,
      phase:       json['phase']       as String,
      diceValue:   json['diceValue']   as int?,
      validMoves: rawValidMoves.map((m) {
        final moveMap = (m as Map<dynamic, dynamic>)
            .map((k, v) => MapEntry(k.toString(), v));
        return ResumeValidMove.fromJson(moveMap);
      }).toList(),
      players: rawPlayers.map((p) {
        final playerMap = (p as Map<dynamic, dynamic>)
            .map((k, v) => MapEntry(k.toString(), v));
        return ResumePlayerState.fromJson(playerMap);
      }).toList(),
      opponent: Opponent.fromJson(opponentMap),
    );
  }

  @override
  String toString() =>
      'ResumeGameState(matchId: $matchId, roomCode: $roomCode, '
      'currentTurn: $currentTurn, phase: $phase, diceValue: $diceValue, '
      'validMoves: $validMoves, players: $players, opponent: $opponent)';
}
