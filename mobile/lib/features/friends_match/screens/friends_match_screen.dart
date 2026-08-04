import 'package:flutter/material.dart';

import '../../matchmaking/screens/game_setup_lobby_screen.dart';
import 'join_room_screen.dart';

// ─── Dark arcade palette (matches app theme) ──────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Friends Match entry screen.
///
/// Presents two actions — Create Room and Join Room.  Neither action has
/// networking or room-code logic yet; both push a placeholder screen.
class FriendsMatchScreen extends StatelessWidget {
  const FriendsMatchScreen({super.key});

  void _push(BuildContext context, String label) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _NextStepScreen(label: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Friends Match',
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Icon + heading ────────────────────────────────────────────
            const Icon(Icons.group, color: _kGold, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Friends Match',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Play with your friends',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 56),

            // ── Create Room ───────────────────────────────────────────────
            _ActionButton(
              key: const Key('friends_match_create_room'),
              icon: Icons.add_circle_outline,
              label: 'Create Room',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const GameSetupLobbyScreen(isFriendMode: true),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Join Room ─────────────────────────────────────────────────
            _ActionButton(
              key: const Key('friends_match_join_room'),
              icon: Icons.login_outlined,
              label: 'Join Room',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const JoinRoomScreen(),
                ),
              ),
              outlined: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── "Coming Next Step" placeholder ──────────────────────────────────────────

class _NextStepScreen extends StatelessWidget {
  const _NextStepScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          label,
          style: const TextStyle(
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
      body: Center(
        child: Text(
          '$label - Coming Next Step',
          style: const TextStyle(
            color: _kTextSecondary,
            fontSize: 18,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ─── Reusable action button ───────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final IconData    icon;
  final String      label;
  final VoidCallback onPressed;
  final bool        outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kPrimary,
          side: const BorderSide(color: _kPrimary),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    );
  }
}
