import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/models/dice_rolled.dart';
import '../../game/models/game_over.dart';
import '../../game/models/pawn_moved.dart';
import '../../game/models/turn_changed.dart';
import '../../game/models/valid_move.dart';
import '../../game/services/game_service.dart';
import '../../game/widgets/ludo_board_widget.dart';
import '../../matchmaking/models/game_started.dart';
import '../../matchmaking/models/match_found.dart';
import '../../matchmaking/services/game_lobby_service.dart';

// ─── Dark arcade palette (consistent with all existing screens) ───────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kGreen         = Color(0xFF4CAF50);
const _kRed           = Color(0xFFFF4C4C);

// ─── GameScreen ───────────────────────────────────────────────────────────────

/// Game session scaffold — Phase 6.7.3.
///
/// Displayed after both players have joined the lobby and the server emits
/// `game_start`.  This screen wires live game state into the board and dice UI:
///
///  - [LudoBoardWidget] renders all pawn positions, updated on each
///    `pawn_moved` event.
///  - [_DiceWidget] shows the current dice value and a ROLL button, enabled
///    only on the local player's turn before the dice has been rolled.
///  - [_ValidMovesPanel] lists move buttons for each valid pawn, shown after
///    the local player rolls and has legal moves.
///  - [_TurnBanner] reflects the live `_currentTurn` colour, updated on each
///    `turn_changed` event.
///
/// Phase 5.6 behaviour retained:
///  - The forfeit button emits `forfeit` via [GameLobbyService] and waits for
///    `game_over`.
///  - A game-over overlay appears on `game_over` for both players.
///  - [onGameOver] is called after dismissal so the parent pops the stack.
///
/// Architecture:
///  - Stateful — subscribes to [GameService] and [GameLobbyService] streams.
///  - Constructor DI only — no singletons or static references.
///  - The screen never calls [Navigator] itself.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.gameService,
    required this.gameLobbyService,
    required this.gameStarted,
    required this.matchFound,
    required this.myUserId,
    required this.onGameOver,
    required this.onSessionExpired,
  });

  /// The service that manages in-game socket events (`roll_dice`, `move_pawn`,
  /// `dice_rolled`, `pawn_moved`, `turn_changed`).
  final GameService gameService;

  /// The service instance shared with [GameLobbyScreen] — holds the live
  /// socket connection and the [GameLobbyService.onGameOver] stream.
  final GameLobbyService gameLobbyService;

  /// The `game_start` payload received from the server.
  final GameStarted gameStarted;

  /// The `match_found` payload that preceded the lobby; carries opponent
  /// info, assigned colour, and room code.
  final MatchFound matchFound;

  /// The authenticated local player's UUID, as issued by the backend.
  ///
  /// Used by [_GameOverOverlay] to compare against [GameOver.winnerId]
  /// (also a UUID) so the overlay shows the correct YOU WIN / YOU LOSE result.
  final String myUserId;

  /// Called when the player dismisses the game-over overlay.
  final void Function(GameOver) onGameOver;

  /// Called if the session expires during this screen.
  final VoidCallback onSessionExpired;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // ── Lobby service subscriptions ──────────────────────────────────────────
  StreamSubscription<GameOver>? _gameOverSub;

  // ── GameService subscriptions ─────────────────────────────────────────────
  StreamSubscription<DiceRolled>?  _diceRolledSub;
  StreamSubscription<PawnMoved>?   _pawnMovedSub;
  StreamSubscription<TurnChanged>? _turnChangedSub;

  // ── Game-over / forfeit state ─────────────────────────────────────────────
  GameOver? _gameOver;
  bool      _forfeiting = false;

  // ── Live gameplay state ───────────────────────────────────────────────────

  /// Colour-relative pawn positions for all four colours (0 = yard, 1–51 =
  /// track, 52–56 = home column, 57 = finished).
  ///
  /// All pawns start in the yard (position 0) and are updated on each
  /// `pawn_moved` event.
  final Map<String, List<int>> _pawns = {
    'red':    [0, 0, 0, 0],
    'blue':   [0, 0, 0, 0],
    'green':  [0, 0, 0, 0],
    'yellow': [0, 0, 0, 0],
  };

  /// Board colour of the player whose turn it currently is.
  ///
  /// Initialised from [GameStarted.firstTurn] and updated on each
  /// `turn_changed` event.
  late String _currentTurn;

  /// Most recent dice value (1–6), or `null` before the first roll of the
  /// current turn.  Reset to `null` on each `turn_changed` event.
  int? _diceValue;

  /// Valid moves for the local player after rolling the dice.
  ///
  /// Populated from `dice_rolled` only when `event.color == myColor`.
  /// Cleared on `pawn_moved` and `turn_changed`.
  List<ValidMove> _validMoves = [];

  /// True from the moment the local player taps ROLL until `dice_rolled`
  /// (or `turn_changed`) is received.
  bool _rolling = false;

  /// Index of the pawn the local player has tapped to move.
  ///
  /// Set when the player taps a pawn-move button; cleared on `pawn_moved`,
  /// `turn_changed`, and `game_over`.  Drives the selection highlight on
  /// [LudoBoardWidget].
  int? _selectedPawnIndex;

  // ── Convenience getters ───────────────────────────────────────────────────

  String get _myColor   => widget.matchFound.color;
  bool   get _isMyTurn  => _currentTurn == _myColor;

  /// Whether the local player may tap ROLL right now.
  bool get _canRoll =>
      _isMyTurn      &&
      _diceValue == null &&
      !_rolling      &&
      !_forfeiting   &&
      _gameOver == null;

  /// Whether the local player may tap a pawn-move button right now.
  bool get _canMove =>
      _isMyTurn          &&
      _diceValue != null &&
      _validMoves.isNotEmpty &&
      _gameOver == null;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentTurn = widget.gameStarted.firstTurn;

    widget.gameService.startListening();

    _diceRolledSub  = widget.gameService.onDiceRolled.listen(_onDiceRolled);
    _pawnMovedSub   = widget.gameService.onPawnMoved.listen(_onPawnMoved);
    _turnChangedSub = widget.gameService.onTurnChanged.listen(_onTurnChanged);

    _gameOverSub =
        widget.gameLobbyService.onGameOver.listen(_onGameOverReceived);
  }

  @override
  void dispose() {
    _diceRolledSub?.cancel();
    _pawnMovedSub?.cancel();
    _turnChangedSub?.cancel();
    _gameOverSub?.cancel();
    widget.gameService.stopListening();
    super.dispose();
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  void _onDiceRolled(DiceRolled event) {
    if (!mounted) return;
    setState(() {
      _diceValue = event.value;
      _rolling   = false;
      // Only populate valid moves for the local player's own rolls.
      _validMoves = event.color == _myColor ? event.validMoves : [];
    });
  }

  void _onPawnMoved(PawnMoved event) {
    if (!mounted) return;
    setState(() {
      final positions = _pawns[event.color];
      if (positions != null && event.pawnIndex < positions.length) {
        positions[event.pawnIndex] = event.toPosition;
      }
      // Send captured pawn back to yard.
      final cc = event.capturedColor;
      final ci = event.capturedPawnIndex;
      if (cc != null && ci != null) {
        final captured = _pawns[cc];
        if (captured != null && ci < captured.length) {
          captured[ci] = 0;
        }
      }
      _validMoves        = [];
      _selectedPawnIndex = null;
    });
  }

  void _onTurnChanged(TurnChanged event) {
    if (!mounted) return;
    setState(() {
      _currentTurn       = event.nextTurn;
      _diceValue         = null;
      _validMoves        = [];
      _rolling           = false;
      _selectedPawnIndex = null;
    });
  }

  void _onGameOverReceived(GameOver event) {
    if (mounted) {
      setState(() {
        _gameOver          = event;
        _forfeiting        = false;
        // Clear all in-flight gameplay state so no stale UI remains visible.
        _validMoves        = [];
        _diceValue         = null;
        _rolling           = false;
        _selectedPawnIndex = null;
      });
    }
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void _onRollPressed() {
    if (!_canRoll) return;
    setState(() => _rolling = true);
    widget.gameService.rollDice(widget.gameStarted.matchId);
  }

  void _onMovePawn(int pawnIndex) {
    if (!_canMove) return;
    widget.gameService.movePawn(widget.gameStarted.matchId, pawnIndex);
    setState(() {
      _validMoves        = [];
      _selectedPawnIndex = pawnIndex;
    });
  }

  Future<void> _onForfeitPressed() async {
    if (_forfeiting || _gameOver != null) return;
    setState(() => _forfeiting = true);
    widget.gameLobbyService.forfeit(widget.gameStarted.matchId);
  }

  void _onDismissResult() {
    final result = _gameOver;
    if (result != null) widget.onGameOver(result);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Board fills the available width minus horizontal padding, capped at 360.
    final boardSize   = (screenWidth - 48).clamp(240.0, 360.0);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        key: const Key('game_screen_app_bar'),
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Game',
          style: TextStyle(
            color: _kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Live turn banner ──────────────────────────────────────
                  _TurnBanner(
                    currentTurn: _currentTurn,
                    myColor:     _myColor,
                  ),
                  const SizedBox(height: 16),

                  // ── Match information card ────────────────────────────────
                  _MatchInfoCard(
                    matchFound:  widget.matchFound,
                    gameStarted: widget.gameStarted,
                  ),
                  const SizedBox(height: 16),

                  // ── Live Ludo board ───────────────────────────────────────
                  Center(
                    child: LudoBoardWidget(
                      key:               const Key('ludo_board'),
                      boardSize:         boardSize,
                      pawns:             _pawns,
                      validPawnIndices:  _canMove
                          ? _validMoves.map((m) => m.pawnIndex).toList()
                          : null,
                      validColor:        _canMove ? _myColor : null,
                      selectedPawnIndex: _selectedPawnIndex,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Dice area ─────────────────────────────────────────────
                  _DiceWidget(
                    diceValue: _diceValue,
                    canRoll:   _canRoll,
                    rolling:   _rolling,
                    onRoll:    _onRollPressed,
                  ),

                  // ── Valid-move buttons (shown only when applicable) ────────
                  if (_canMove) ...[
                    const SizedBox(height: 8),
                    _ValidMovesPanel(
                      validMoves:  _validMoves,
                      onMovePawn:  _onMovePawn,
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Forfeit button ────────────────────────────────────────
                  _ForfeitButton(
                    onPressed: _forfeiting || _gameOver != null
                        ? null
                        : _onForfeitPressed,
                    forfeiting: _forfeiting,
                  ),
                ],
              ),
            ),
          ),

          // ── Game-over overlay ─────────────────────────────────────────────
          if (_gameOver != null)
            _GameOverOverlay(
              gameOver:  _gameOver!,
              myUserId:  widget.myUserId,
              onDismiss: _onDismissResult,
            ),
        ],
      ),
    );
  }
}

// ─── Private helper widgets ───────────────────────────────────────────────────

/// Banner that shows which player's turn it currently is.
///
/// Updated live on each `turn_changed` event; initialised from
/// [GameStarted.firstTurn].
class _TurnBanner extends StatelessWidget {
  const _TurnBanner({
    required this.currentTurn,
    required this.myColor,
  });

  final String currentTurn;
  final String myColor;

  static Color _toFlutterColor(String name) => switch (name) {
        'red'    => const Color(0xFFFF4C4C),
        'blue'   => const Color(0xFF4C8EFF),
        'green'  => const Color(0xFF4CAF50),
        'yellow' => const Color(0xFFFFC107),
        _        => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final isMyTurn = currentTurn == myColor;
    final color    = _toFlutterColor(currentTurn);
    final label    = isMyTurn
        ? 'Your turn (${currentTurn.toUpperCase()})'
        : "Opponent's turn (${currentTurn.toUpperCase()})";

    return Container(
      key: const Key('turn_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              key: const Key('turn_text'),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing match info: opponent, assigned colour, room code.
class _MatchInfoCard extends StatelessWidget {
  const _MatchInfoCard({
    required this.matchFound,
    required this.gameStarted,
  });

  final MatchFound  matchFound;
  final GameStarted gameStarted;

  static Color _toFlutterColor(String name) => switch (name) {
        'red'    => const Color(0xFFFF4C4C),
        'blue'   => const Color(0xFF4C8EFF),
        'green'  => const Color(0xFF4CAF50),
        'yellow' => const Color(0xFFFFC107),
        _        => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final myChipColor = _toFlutterColor(matchFound.color);

    return Container(
      key: const Key('match_info_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: const Color(0xFF2D2D4E)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opponent row
          Row(
            children: [
              _GameAvatar(
                fullName:  matchFound.opponent.fullName,
                avatarUrl: matchFound.opponent.avatar,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Opponent',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    matchFound.opponent.fullName,
                    key: const Key('opponent_name'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2D2D4E), height: 1),
          const SizedBox(height: 16),

          // My colour
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your colour',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
              Container(
                key: const Key('my_color_chip'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: myChipColor.withValues(alpha: 0.2),
                  border: Border.all(color: myChipColor),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  matchFound.color.toUpperCase(),
                  style: TextStyle(
                    color: myChipColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Room code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Room',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
              Text(
                matchFound.roomCode,
                key: const Key('room_code'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular avatar with initials fallback.
class _GameAvatar extends StatelessWidget {
  const _GameAvatar({required this.fullName, this.avatarUrl});

  final String  fullName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initials = fullName.trim().isEmpty
        ? '?'
        : fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return CircleAvatar(
      radius: 24,
      backgroundColor: _kPrimary,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

/// Dice display and roll button.
///
/// Shows the current dice value (1–6) inside a styled square, or a "?" when
/// the dice has not yet been rolled this turn.  The ROLL button is enabled
/// only when [canRoll] is true.
class _DiceWidget extends StatelessWidget {
  const _DiceWidget({
    required this.diceValue,
    required this.canRoll,
    required this.rolling,
    required this.onRoll,
  });

  final int?  diceValue;
  final bool  canRoll;
  final bool  rolling;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dice_area'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Dice face ──────────────────────────────────────────────────
          Container(
            key: const Key('dice_face'),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kBg,
              border: Border.all(
                color: diceValue != null
                    ? _kGold.withValues(alpha: 0.8)
                    : _kBorder,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                diceValue != null ? '$diceValue' : '?',
                key: const Key('dice_value'),
                style: TextStyle(
                  color: diceValue != null ? _kGold : _kTextSecondary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ── Roll button ────────────────────────────────────────────────
          SizedBox(
            width: 140,
            child: ElevatedButton.icon(
              key: const Key('roll_button'),
              onPressed: canRoll ? onRoll : null,
              icon: rolling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        key: Key('roll_spinner'),
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.casino_outlined, size: 18),
              label: Text(
                rolling ? 'ROLLING\u2026' : 'ROLL',
                key: const Key('roll_label'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kBorder,
                disabledForegroundColor: _kTextSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of move buttons, one for each pawn in [validMoves].
///
/// Shown only when it is the local player's turn and the dice has been
/// rolled with at least one legal move.
class _ValidMovesPanel extends StatelessWidget {
  const _ValidMovesPanel({
    required this.validMoves,
    required this.onMovePawn,
  });

  final List<ValidMove>   validMoves;
  final void Function(int pawnIndex) onMovePawn;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('valid_moves_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a pawn to move:',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: validMoves.map((move) {
              return ElevatedButton(
                key: Key('move_pawn_${move.pawnIndex}'),
                onPressed: () => onMovePawn(move.pawnIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'PAWN ${move.pawnIndex + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Forfeit button — sends the forfeit request to the server.
///
/// [onPressed] is null when a forfeit is already in flight or the game is over.
/// [forfeiting] shows a loading spinner in place of the flag icon.
class _ForfeitButton extends StatelessWidget {
  const _ForfeitButton({
    required this.onPressed,
    required this.forfeiting,
  });

  final VoidCallback? onPressed;
  final bool          forfeiting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('forfeit_button'),
        onPressed: onPressed,
        icon: forfeiting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  key: Key('forfeit_spinner'),
                  strokeWidth: 2,
                  color: _kRed,
                ),
              )
            : const Icon(Icons.flag_outlined),
        label: Text(
          forfeiting ? 'FORFEITING\u2026' : 'FORFEIT',
          key: const Key('forfeit_label'),
          style: const TextStyle(letterSpacing: 1.2),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kRed,
          side: BorderSide(color: _kRed.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Full-screen overlay shown when the server emits `game_over`.
///
/// [myUserId] must be the local player's UUID as issued by the backend — the
/// same type as [GameOver.winnerId].  Win/loss is determined by comparing
/// `gameOver.winnerId == myUserId` so that the result is always accurate
/// regardless of which player the server designates as winner.
class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.gameOver,
    required this.myUserId,
    required this.onDismiss,
  });

  final GameOver     gameOver;
  final String       myUserId;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isWinner = gameOver.winnerId == myUserId;
    final title    = isWinner ? 'YOU WIN! 🎉' : 'YOU LOSE';
    final subtitle = gameOver.reason == 'forfeit'
        ? (isWinner ? 'Opponent forfeited.' : 'You forfeited.')
        : gameOver.reason == 'completed'
            ? (isWinner ? 'You finished all pawns!' : 'Opponent finished first.')
            : (isWinner
                ? 'Opponent disconnected.'
                : 'You were disconnected.');
    final accentColor = isWinner ? _kGreen : _kRed;

    return Container(
      key: const Key('game_over_overlay'),
      color: _kBg.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            key: const Key('game_over_card'),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border.all(color: accentColor.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  key: const Key('game_over_title'),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  key: const Key('game_over_subtitle'),
                  style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('game_over_continue_button'),
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
