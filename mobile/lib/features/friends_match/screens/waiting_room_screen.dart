import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Dark arcade palette (matches app theme) ──────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kGreen         = Color(0xFF4CAF50);

/// Waiting Room — shown after Create Room or Join Room.
///
/// Displays the room code, a Copy button, selected settings (host only),
/// joined player count, and a waiting indicator.
/// No backend or Socket.IO logic — navigation only.
class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
    required this.players,
    required this.entryPoints,
    required this.pawnCount,
    required this.boardColor,
  });

  final String roomCode;

  /// True when this player created the room; false when joining.
  final bool   isHost;

  final int    players;
  final int    entryPoints;
  final int    pawnCount;
  final String boardColor;

  static const Map<String, Color> _colorValues = {
    'Red':    Color(0xFFFF4C4C),
    'Yellow': Color(0xFFFFC107),
    'Green':  Color(0xFF4CAF50),
    'Blue':   Color(0xFF4C8EFF),
  };

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room code copied to clipboard.'),
        backgroundColor: _kSurface,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardFlutterColor =
        _colorValues[boardColor] ?? const Color(0xFF9E9E9E);
    final joinedCount = 1; // UI only — no backend yet

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Waiting Room',
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
            // ── Room Code ─────────────────────────────────────────────────
            _SectionLabel(label: 'ROOM CODE'),
            const SizedBox(height: 12),
            Center(
              child: Text(
                roomCode,
                key: const Key('room_code_text'),
                style: const TextStyle(
                  color: _kGold,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('copy_code_button'),
              onPressed: () => _copyCode(context),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Room Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Divider ───────────────────────────────────────────────────
            Container(height: 1, color: _kBorder),
            const SizedBox(height: 24),

            // ── Selected Settings ─────────────────────────────────────────
            _SectionLabel(label: 'MATCH SETTINGS'),
            const SizedBox(height: 16),
            _SettingRow(
              icon: Icons.group_outlined,
              label: 'Players',
              value: '$players',
            ),
            const SizedBox(height: 12),
            _SettingRow(
              icon: Icons.stars_outlined,
              label: 'Entry Points',
              value: '$entryPoints',
            ),
            const SizedBox(height: 12),
            _SettingRow(
              icon: Icons.circle_outlined,
              label: 'Pawn Count',
              value: '$pawnCount',
            ),
            const SizedBox(height: 12),
            _SettingRow(
              icon: Icons.palette_outlined,
              label: 'Board Color',
              value: boardColor,
              valueColor: boardFlutterColor,
            ),
            const SizedBox(height: 28),

            // ── Divider ───────────────────────────────────────────────────
            Container(height: 1, color: _kBorder),
            const SizedBox(height: 24),

            // ── Joined Players ────────────────────────────────────────────
            _SectionLabel(label: 'PLAYERS'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$joinedCount',
                  key: const Key('joined_count'),
                  style: const TextStyle(
                    color: _kGreen,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' / $players',
                  style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'joined',
                style: TextStyle(color: _kTextSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 28),

            // ── Waiting indicator ─────────────────────────────────────────
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_kPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Waiting for players to join...',
                key: Key('waiting_status_text'),
                style: TextStyle(
                  color: _kTextSecondary,
                  fontSize: 15,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // ── Cancel / Leave button ─────────────────────────────────────
            OutlinedButton(
              key: const Key('cancel_room_button'),
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isHost ? 'Cancel Room' : 'Leave Room'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Private helpers ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _kTextSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kTextSecondary, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: _kTextSecondary, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
