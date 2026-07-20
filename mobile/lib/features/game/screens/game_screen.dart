import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/models/game_over.dart';
import '../../game/services/game_service.dart';
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

/// Game session scaffold — Phase 5.5 / 5.6.
///
/// Displayed after both players have joined the lobby and the server emits
/// `game_start`.  This screen is a **placeholder only**: it shows match
/// information and a forfeit button but contains no gameplay logic.
///
/// Phase 6 will replace the placeholder board with the real Ludo board,
/// dice, pawn movement, and turn/timer logic.
///
/// Phase 5.6 additions:
///  - The forfeit button emits `forfeit` to the server via [GameLobbyService]
///    and then waits for the server's `game_over` response.
///  - A game-over result overlay is shown when `game_over` is received from
///    the server (covers both the forfeiting player and the winning player).
///  - [onGameOver] is called after the player dismisses the overlay so the
///    parent ([MainShell]) can pop the navigation stack back to the shell root.
///
/// Architecture:
///  - Stateful — needs to subscribe to [GameLobbyService.onGameOver] and
///    maintain [_gameOver] / [_forfeiting] state.
///  - Constructor DI only — no singletons or static references.
///  - The screen never calls [Navigator] itself; routing is the parent's
///    responsibility via [onGameOver] and [onSessionExpired].
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.gameService,
    required this.gameLobbyService,
    required this.gameStarted,
    required this.matchFound,
    required this.onGameOver,
    required this.onSessionExpired,
  });

  /// The service that manages in-game socket events (`roll_dice`, `move_pawn`,
  /// `dice_rolled`, `pawn_moved`, `turn_changed`).  Injected from [MainShell]
  /// so the same [SocketClient] is shared across the game session.
  final GameService gameService;

  /// The service instance shared with [GameLobbyScreen] — holds the live
  /// socket connection and the [GameLobbyService.onGameOver] stream.
  final GameLobbyService gameLobbyService;

  /// The `game_start` payload received from the server.
  final GameStarted gameStarted;

  /// The `match_found` payload that preceded the lobby; carries opponent
  /// info, assigned colour, and room code.
  final MatchFound matchFound;

  /// Called when the player dismisses the game-over overlay.  The parent
  /// ([MainShell]) is responsible for popping the navigation stack.
  final void Function(GameOver) onGameOver;

  /// Called if the session expires during this screen.  The parent clears
  /// the session and routes to the login screen.
  final VoidCallback onSessionExpired;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  StreamSubscription<GameOver>? _gameOverSub;

  /// Non-null once the server has emitted `game_over`.
  GameOver? _gameOver;

  /// True while waiting for the server's `game_over` after tapping Forfeit.
  bool _forfeiting = false;

  @override
  void initState() {
    super.initState();
    widget.gameService.startListening();
    _gameOverSub =
        widget.gameLobbyService.onGameOver.listen(_onGameOverReceived);
  }

  @override
  void dispose() {
    _gameOverSub?.cancel();
    widget.gameService.stopListening();
    super.dispose();
  }

  void _onGameOverReceived(GameOver event) {
    if (mounted) {
      setState(() {
        _gameOver   = event;
        _forfeiting = false;
      });
    }
  }

  Future<void> _onForfeitPressed() async {
    if (_forfeiting || _gameOver != null) return;
    setState(() => _forfeiting = true);
    widget.gameLobbyService.forfeit(widget.gameStarted.matchId);
    // _forfeiting stays true until onGameOver fires (or screen is disposed).
  }

  void _onDismissResult() {
    final result = _gameOver;
    if (result != null) {
      widget.onGameOver(result);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  // ── First turn banner ─────────────────────────────────────
                  _FirstTurnBanner(
                    firstTurn: widget.gameStarted.firstTurn,
                    myColor:   widget.matchFound.color,
                  ),
                  const SizedBox(height: 20),

                  // ── Match information card ────────────────────────────────
                  _MatchInfoCard(
                    matchFound:  widget.matchFound,
                    gameStarted: widget.gameStarted,
                  ),
                  const SizedBox(height: 20),

                  // ── Placeholder board ─────────────────────────────────────
                  const _PlaceholderBoard(),
                  const SizedBox(height: 24),

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
              gameOver:     _gameOver!,
              myUserId:     '', // Phase 6 will thread userId; for now, server
                                // winnerId is opaque to the client UI.
              matchFound:   widget.matchFound,
              onDismiss:    _onDismissResult,
            ),
        ],
      ),
    );
  }
}

// ─── Private helper widgets ───────────────────────────────────────────────────

/// Banner that announces whose turn it is first.
class _FirstTurnBanner extends StatelessWidget {
  const _FirstTurnBanner({
    required this.firstTurn,
    required this.myColor,
  });

  final String firstTurn;
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
    final isMyTurn = firstTurn == myColor;
    final color    = _toFlutterColor(firstTurn);
    final label    = isMyTurn
        ? 'You go first! (${firstTurn.toUpperCase()})'
        : 'Opponent goes first (${firstTurn.toUpperCase()})';

    return Container(
      key: const Key('first_turn_banner'),
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
              key: const Key('first_turn_text'),
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

/// Placeholder Ludo board — replaced by the real board in Phase 6.
class _PlaceholderBoard extends StatelessWidget {
  const _PlaceholderBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('placeholder_board'),
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: const Color(0xFF2D2D4E)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_4x4_outlined, color: Color(0xFF2D2D4E), size: 64),
          SizedBox(height: 16),
          Text(
            'Board coming in Phase 6',
            key: Key('placeholder_board_text'),
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
              letterSpacing: 0.4,
            ),
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
/// Displays whether this player won or lost and the reason.
/// Tapping the "CONTINUE" button fires [onDismiss] which lets the parent
/// navigate away.
///
/// Note: In Phase 5.6 we do not thread the current user's ID down to
/// [GameScreen], so the win/loss determination relies on the [MatchFound]
/// opponent's player ID.  Phase 6 will refine this once user context is
/// fully available in the game layer.
class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.gameOver,
    required this.myUserId,
    required this.matchFound,
    required this.onDismiss,
  });

  final GameOver   gameOver;
  final String     myUserId;
  final MatchFound matchFound;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isWinner = gameOver.winnerId != matchFound.opponent.playerId;
    final title    = isWinner ? 'YOU WIN! 🎉' : 'YOU LOSE';
    final subtitle = gameOver.reason == 'forfeit'
        ? (isWinner ? 'Opponent forfeited.' : 'You forfeited.')
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
