import 'package:flutter/material.dart';

import '../../matchmaking/models/game_started.dart';
import '../../matchmaking/models/match_found.dart';

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

/// Game session scaffold — Phase 5.5.
///
/// Displayed after both players have joined the lobby and the server emits
/// `game_start`.  This screen is a **placeholder only**: it shows match
/// information and a forfeit button but contains no gameplay logic.
///
/// Phase 6 will replace the placeholder board with the real Ludo board,
/// dice, pawn movement, and turn/timer logic.
///
/// Architecture:
///  - Stateless — no services required for the scaffold.
///  - Constructor DI only — no singletons or static references.
///  - The screen never calls [Navigator] itself; routing is the parent's
///    responsibility via [onForfeit] and [onSessionExpired].
class GameScreen extends StatelessWidget {
  const GameScreen({
    super.key,
    required this.gameStarted,
    required this.matchFound,
    required this.onForfeit,
    required this.onSessionExpired,
  });

  /// The `game_start` payload received from the server.
  final GameStarted gameStarted;

  /// The `match_found` payload that preceded the lobby; carries opponent
  /// info, assigned colour, and room code.
  final MatchFound matchFound;

  /// Called when the player taps the Forfeit button.  The parent
  /// ([MainShell]) is responsible for popping the navigation stack.
  final VoidCallback onForfeit;

  /// Called if the session expires during this screen.  The parent clears
  /// the session and routes to the login screen.
  final VoidCallback onSessionExpired;

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── First turn banner ─────────────────────────────────────────
              _FirstTurnBanner(
                firstTurn: gameStarted.firstTurn,
                myColor:   matchFound.color,
              ),
              const SizedBox(height: 20),

              // ── Match information card ────────────────────────────────────
              _MatchInfoCard(
                matchFound:  matchFound,
                gameStarted: gameStarted,
              ),
              const SizedBox(height: 20),

              // ── Placeholder board ─────────────────────────────────────────
              const _PlaceholderBoard(),
              const SizedBox(height: 24),

              // ── Forfeit button ────────────────────────────────────────────
              _ForfeitButton(onPressed: onForfeit),
            ],
          ),
        ),
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
                  Text(
                    'Opponent',
                    style: const TextStyle(
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

/// Forfeit button — ends the game and returns to the shell.
class _ForfeitButton extends StatelessWidget {
  const _ForfeitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('forfeit_button'),
        onPressed: onPressed,
        icon: const Icon(Icons.flag_outlined),
        label: const Text(
          'FORFEIT',
          style: TextStyle(letterSpacing: 1.2),
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
