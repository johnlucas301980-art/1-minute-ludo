import 'dart:math';

import 'package:flutter/material.dart';

import '../../friends_match/screens/waiting_room_screen.dart';

// ─── Dark arcade palette (matches app theme) ──────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Game Setup Lobby — configure match options before online or friend matchmaking.
///
/// When [isFriendMode] is false (default) the bottom button reads **PLAY** and
/// shows a placeholder snackbar — matchmaking wiring comes in the next step.
///
/// When [isFriendMode] is true the bottom button reads **CREATE ROOM**; pressing
/// it generates a room code and navigates to [WaitingRoomScreen].
class GameSetupLobbyScreen extends StatefulWidget {
  const GameSetupLobbyScreen({
    super.key,
    this.isFriendMode = false,
  });

  /// Set to `true` when reached from Friend Match → Create Room.
  final bool isFriendMode;

  @override
  State<GameSetupLobbyScreen> createState() => _GameSetupLobbyScreenState();
}

class _GameSetupLobbyScreenState extends State<GameSetupLobbyScreen> {
  int    _players     = 2;
  int    _entryPoints = 10;
  int    _pawnCount   = 1;
  String _boardColor  = 'Red';

  static const List<int>    _playerOptions     = [2, 3, 4];
  static const List<int>    _entryPointOptions = [10, 20, 50, 100];
  static const List<int>    _pawnCountOptions  = [1, 2, 3, 4];
  static const List<String> _boardColorOptions = ['Red', 'Yellow', 'Green', 'Blue'];

  static const Map<String, Color> _boardColorValues = {
    'Red':    Color(0xFFFF4C4C),
    'Yellow': Color(0xFFFFC107),
    'Green':  Color(0xFF4CAF50),
    'Blue':   Color(0xFF4C8EFF),
  };

  // ─── Room code generation ─────────────────────────────────────────────────

  static String _generateRoomCode() {
    const chars  = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ─── Reward calculation ───────────────────────────────────────────────────

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _buildRewardText() {
    final ep = _entryPoints;

    if (_players == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 Winner Reward',
            style: TextStyle(
              color: _kGold,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entry Points × 1.5 = ${_fmt(ep * 1.5)}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      );
    }

    if (_players == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 1st Place',
            style: TextStyle(
              color: _kGold,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entry Points × 1.5 = ${_fmt(ep * 1.5)}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            '🥈 2nd Place',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entry Points × 1 = ${_fmt(ep * 1.0)}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      );
    }

    // 4 players
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏆 1st Place',
          style: TextStyle(
            color: _kGold,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Entry Points × 2 = ${_fmt(ep * 2.0)}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 12),
        const Text(
          '🥈 2nd Place',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Entry Points × 1 = ${_fmt(ep * 1.0)}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  // ─── Shared dropdown builder ──────────────────────────────────────────────

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? display,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _kSurface,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: _kSurface,
              iconEnabledColor: _kTextSecondary,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                          display != null ? display(item) : item.toString()),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Board color selector ─────────────────────────────────────────────────

  Widget _buildBoardColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BOARD COLOR',
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _boardColorOptions.map((name) {
            final color    = _boardColorValues[name]!;
            final selected = name == _boardColor;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  key: Key('board_color_$name'),
                  onTap: () => setState(() => _boardColor = name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? color
                          : color.withValues(alpha: 0.25),
                      border: Border.all(
                        color: selected ? Colors.white : color,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: selected ? Colors.white : color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Button action ────────────────────────────────────────────────────────

  void _onActionPressed() {
    if (widget.isFriendMode) {
      final roomCode = _generateRoomCode();
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WaitingRoomScreen(
            roomCode:    roomCode,
            isHost:      true,
            players:     _players,
            entryPoints: _entryPoints,
            pawnCount:   _pawnCount,
            boardColor:  _boardColor,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Matchmaking will be implemented in the next step.'),
          backgroundColor: _kSurface,
        ),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final actionLabel = widget.isFriendMode ? 'CREATE ROOM' : 'PLAY';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Game Setup',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Players ───────────────────────────────────────────────────
            _buildDropdown<int>(
              label: 'PLAYERS',
              value: _players,
              items: _playerOptions,
              display: (v) => '$v Players',
              onChanged: (v) {
                if (v != null) setState(() => _players = v);
              },
            ),
            const SizedBox(height: 20),

            // ── Entry Points ──────────────────────────────────────────────
            _buildDropdown<int>(
              label: 'ENTRY POINTS',
              value: _entryPoints,
              items: _entryPointOptions,
              onChanged: (v) {
                if (v != null) setState(() => _entryPoints = v);
              },
            ),
            const SizedBox(height: 20),

            // ── Pawn Count ────────────────────────────────────────────────
            _buildDropdown<int>(
              label: 'PAWN COUNT',
              value: _pawnCount,
              items: _pawnCountOptions,
              onChanged: (v) {
                if (v != null) setState(() => _pawnCount = v);
              },
            ),
            const SizedBox(height: 20),

            // ── Board Color ───────────────────────────────────────────────
            _buildBoardColorSelector(),
            const SizedBox(height: 32),

            // ── Divider ───────────────────────────────────────────────────
            Container(height: 1, color: _kBorder),
            const SizedBox(height: 24),

            // ── Dynamic Reward Text ───────────────────────────────────────
            _buildRewardText(),
            const SizedBox(height: 36),

            // ── Action button ─────────────────────────────────────────────
            ElevatedButton(
              key: const Key('action_button'),
              onPressed: _onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(actionLabel),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
