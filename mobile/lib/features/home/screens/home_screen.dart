import 'package:flutter/material.dart';

import '../../game/screens/final_game_screen.dart';
import 'classic_mode_screen.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Home screen — shows Classic Mode and 1 Minute Mode buttons.
///
/// Constructor callbacks are kept for compatibility with [MainShell].
class HomeLobbyScreen extends StatelessWidget {
  const HomeLobbyScreen({
    super.key,
    required this.onOnlineMatch,
    required this.onProfile,
    required this.onLogout,
  });

  final VoidCallback onOnlineMatch;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Classic Mode
              ElevatedButton(
                key: const Key('classic_mode_button'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClassicModeScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text('Classic Mode'),
              ),
              const SizedBox(height: 20),
              // 1 Minute Mode — final game UI
              ElevatedButton(
                key: const Key('one_minute_mode_button'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const FinalGameScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: const Color(0xFF0D0D1A),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text('1 Minute Mode'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
