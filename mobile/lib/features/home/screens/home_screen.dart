import 'package:flutter/material.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D1A);
const _kGold = Color(0xFFFFD700);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Placeholder home screen shown on the Home tab.
///
/// Will be replaced with the live game lobby in a later phase.
///
/// No service dependencies — it is a pure stateless widget.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _kBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_esports,
              key: Key('home_icon'),
              color: _kGold,
              size: 72,
            ),
            SizedBox(height: 24),
            Text(
              '1 Minute Ludo',
              key: Key('home_title'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Game lobby coming soon',
              key: Key('home_tagline'),
              style: TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
