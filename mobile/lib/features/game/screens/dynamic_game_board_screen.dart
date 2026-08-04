// STEP 3
// DYNAMIC GAME BOARD
// Supports 2/3/4 Players
// Supports 1/2/3/4 Pawns
// Supports BOT Seats

import 'package:flutter/material.dart';

import '../models/game_board_config.dart';
import '../widgets/ludo_board_widget.dart';

// ─── Dark arcade palette (consistent with all screens) ───────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kGreen         = Color(0xFF4CAF50);
const _kRed           = Color(0xFFFF4C4C);

/// Dynamic Game Board screen — STEP 3.
///
/// Receives a fully-configured [GameBoardConfig] produced by the matchmaking
/// flow and renders the Ludo board adapted to the actual match parameters:
///
///  - Correct number of active yard corners for 2, 3, or 4 players.
///  - Correct number of pawn placeholder circles per yard (1–4).
///  - Player roster strip showing each seat's assigned colour and type
///    (Human / BOT).
///  - All pawns initialised in their yard positions (all at position 0).
///
/// Socket wiring (dice, pawn movement, game-over) is NOT implemented in
/// STEP 3 — this screen establishes the visual configuration layer only.
/// Live gameplay will be connected in a subsequent step.
class DynamicGameBoardScreen extends StatefulWidget {
  const DynamicGameBoardScreen({
    super.key,
    required this.config,
  });

  /// The complete board configuration derived from game-setup and matchmaking.
  final GameBoardConfig config;

  @override
  State<DynamicGameBoardScreen> createState() => _DynamicGameBoardScreenState();
}

class _DynamicGameBoardScreenState extends State<DynamicGameBoardScreen> {
  /// Pawn positions for every active colour — all start in the yard (0).
  ///
  /// Keys are lowercase colour names; values are lists of [pawnCount] zeroes.
  late final Map<String, List<int>> _pawns;

  @override
  void initState() {
    super.initState();

    // STEP 3: Build the pawn map dynamically from the config.
    // Each active player slot gets exactly config.pawnCount pawns, all in yard.
    _pawns = {
      for (final slot in widget.config.slots)
        slot.color: List.filled(widget.config.pawnCount, 0),
    };
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize   = (screenWidth - 48).clamp(240.0, 360.0);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        key: const Key('dynamic_game_board_app_bar'),
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
        iconTheme: const IconThemeData(color: _kTextSecondary),
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
              // ── Player roster ─────────────────────────────────────────────
              _PlayerRoster(slots: widget.config.slots),
              const SizedBox(height: 16),

              // ── Match settings chip row ───────────────────────────────────
              _MatchSettingsRow(
                players:    widget.config.players,
                pawnCount:  widget.config.pawnCount,
              ),
              const SizedBox(height: 16),

              // ── Dynamic Ludo board ────────────────────────────────────────
              Center(
                child: LudoBoardWidget(
                  key:          const Key('dynamic_ludo_board'),
                  boardSize:    boardSize,
                  pawns:        _pawns,
                  activeColors: widget.config.activeColors,
                  pawnCount:    widget.config.pawnCount,
                ),
              ),
              const SizedBox(height: 24),

              // ── Leave button ──────────────────────────────────────────────
              OutlinedButton.icon(
                key: const Key('leave_game_button'),
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                ),
                icon: const Icon(Icons.exit_to_app_outlined),
                label: const Text(
                  'LEAVE GAME',
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Player Roster ────────────────────────────────────────────────────────────

/// Horizontal strip showing all player seats with colour and type badges.
///
/// STEP 3: Renders dynamically for 2, 3, or 4 players.
/// No duplicated UI — slot count drives the layout.
class _PlayerRoster extends StatelessWidget {
  const _PlayerRoster({required this.slots});

  final List<PlayerSlot> slots;

  static Color _toFlutterColor(String name) => switch (name) {
        'red'    => const Color(0xFFFF4C4C),
        'blue'   => const Color(0xFF4C8EFF),
        'green'  => const Color(0xFF4CAF50),
        'yellow' => const Color(0xFFFFC107),
        _        => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('player_roster'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PLAYERS',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: slots.map((slot) {
              final color = _toFlutterColor(slot.color);
              final label = slot.isLocalPlayer
                  ? 'You'
                  : slot.isBot
                      ? 'BOT'
                      : 'Player';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _PlayerSlotCard(
                    color:   color,
                    name:    slot.color.toUpperCase(),
                    label:   label,
                    isMe:    slot.isLocalPlayer,
                    isBot:   slot.isBot,
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

class _PlayerSlotCard extends StatelessWidget {
  const _PlayerSlotCard({
    required this.color,
    required this.name,
    required this.label,
    required this.isMe,
    required this.isBot,
  });

  final Color  color;
  final String name;
  final String label;
  final bool   isMe;
  final bool   isBot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(
          color: isMe ? color : color.withValues(alpha: 0.4),
          width: isMe ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Colour dot
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            ),
          ),
          const SizedBox(height: 5),
          // Colour name
          Text(
            name,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isBot
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                  : isMe
                      ? _kGreen.withValues(alpha: 0.2)
                      : _kTextSecondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isBot
                    ? const Color(0xFF6C63FF)
                    : isMe
                        ? _kGreen
                        : _kTextSecondary,
                fontSize: 8,
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

// ─── Match Settings Row ───────────────────────────────────────────────────────

/// Compact chip row showing the key match parameters.
class _MatchSettingsRow extends StatelessWidget {
  const _MatchSettingsRow({
    required this.players,
    required this.pawnCount,
  });

  final int players;
  final int pawnCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('match_settings_row'),
      children: [
        _Chip(icon: Icons.group_outlined,  label: '$players Players'),
        const SizedBox(width: 8),
        _Chip(icon: Icons.circle_outlined, label: '$pawnCount Pawns each'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _kTextSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _kTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
