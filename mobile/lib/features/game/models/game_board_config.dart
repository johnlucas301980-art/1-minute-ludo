// STEP 3
// DYNAMIC GAME BOARD
// Supports 2/3/4 Players
// Supports 1/2/3/4 Pawns
// Supports BOT Seats

// ---------------------------------------------------------------------------
// Player type
// ---------------------------------------------------------------------------

/// Whether a player seat is occupied by a human or a bot.
///
/// BOT seats are filled automatically by the matchmaking bot-fallback
/// (STEP 2) when the 60-second search timer expires without enough real
/// players.
enum PlayerType { human, bot }

// ---------------------------------------------------------------------------
// PlayerSlot
// ---------------------------------------------------------------------------

/// A single participant seat in a dynamic Ludo match.
///
/// Carries the assigned board colour, whether the seat is a bot or human,
/// and whether this slot represents the local player.
class PlayerSlot {
  const PlayerSlot({
    required this.color,
    required this.type,
    required this.isLocalPlayer,
  });

  /// Lowercase Ludo colour assigned to this seat.
  /// One of: `'red'`, `'blue'`, `'green'`, `'yellow'`.
  final String color;

  /// Human or BOT — set automatically from matchmaking results.
  final PlayerType type;

  /// `true` only for the local player's own seat.
  final bool isLocalPlayer;

  bool get isBot => type == PlayerType.bot;

  @override
  String toString() =>
      'PlayerSlot(color: $color, type: $type, isLocalPlayer: $isLocalPlayer)';
}

// ---------------------------------------------------------------------------
// GameBoardConfig
// ---------------------------------------------------------------------------

/// Full configuration for a dynamic Ludo game session.
///
/// Passed from the matchmaking flow (via [GameBoardConfig.fromMatchmaking])
/// to [DynamicGameBoardScreen] so the board can adapt without any hardcoded
/// player or pawn counts.
///
/// Board colour assignment:
///  - The local player always receives the colour they chose in
///    [GameSetupLobbyScreen].
///  - Additional players (real or bot) are assigned the remaining standard
///    colours in order: red → blue → green → yellow, skipping the local
///    player's colour.
///
/// Active colours:
///  - Only the colours appearing in [slots] are rendered as active yards on
///    the board.  Unused yard corners are rendered in a muted/inactive style.
class GameBoardConfig {
  const GameBoardConfig({
    required this.players,
    required this.pawnCount,
    required this.slots,
  })  : assert(players >= 2 && players <= 4, 'players must be 2, 3, or 4'),
        assert(pawnCount >= 1 && pawnCount <= 4, 'pawnCount must be 1–4'),
        assert(slots.length == players, 'slots.length must equal players');

  /// Total number of participants (2, 3, or 4).
  final int players;

  /// Number of pawns each player receives (1, 2, 3, or 4).
  final int pawnCount;

  /// Ordered list of player seats.
  ///
  /// `slots[0]` is always the local player.  The remaining entries are
  /// opponents in the order they were matched (real players first, bots last).
  final List<PlayerSlot> slots;

  /// Lowercase colour names for every active seat.
  List<String> get activeColors => slots.map((s) => s.color).toList();

  // ── Factory ────────────────────────────────────────────────────────────────

  /// Standard colour assignment order (clockwise from top-left).
  static const List<String> _colorOrder = ['red', 'blue', 'green', 'yellow'];

  /// Build a [GameBoardConfig] from the matchmaking result.
  ///
  /// [boardColor] is the lowercase colour the local player selected in
  /// [GameSetupLobbyScreen] (e.g. `'red'`).
  ///
  /// [realPlayersFound] real opponents were matched before the timeout;
  /// [botsAdded] bot slots were added by the STEP 2 bot fallback to fill
  /// the remaining seats.
  factory GameBoardConfig.fromMatchmaking({
    required int players,
    required int pawnCount,
    required String boardColor,     // lowercase player-chosen colour
    required int realPlayersFound,
    required int botsAdded,
  }) {
    // Validate / normalise the chosen board colour.
    final myColor = _colorOrder.contains(boardColor) ? boardColor : 'red';

    // Build the pool of colours available for opponents (all except myColor).
    final remaining =
        _colorOrder.where((c) => c != myColor).toList();

    final List<PlayerSlot> slots = [
      // Slot 0 — local player (always human).
      PlayerSlot(color: myColor, type: PlayerType.human, isLocalPlayer: true),
    ];

    // Real-player opponent slots.
    final cappedReal =
        realPlayersFound.clamp(0, remaining.length);
    for (var i = 0; i < cappedReal; i++) {
      slots.add(PlayerSlot(
        color: remaining[i],
        type: PlayerType.human,
        isLocalPlayer: false,
      ));
    }

    // BOT opponent slots (filled by STEP 2 bot fallback).
    final cappedBots =
        botsAdded.clamp(0, remaining.length - cappedReal);
    for (var i = 0; i < cappedBots; i++) {
      slots.add(PlayerSlot(
        color: remaining[cappedReal + i],
        type: PlayerType.bot,
        isLocalPlayer: false,
      ));
    }

    return GameBoardConfig(
      players: players,
      pawnCount: pawnCount,
      slots: slots,
    );
  }

  @override
  String toString() =>
      'GameBoardConfig(players: $players, pawnCount: $pawnCount, '
      'slots: $slots)';
}
