import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Dark arcade palette (matches app theme) ──────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Room Lobby screen — UI only, no backend or Socket.IO logic.
///
/// Displays a hardcoded placeholder room code and waiting status.
/// Copy / Share buttons show a "Coming Next Step" message.
/// Cancel Room returns to the previous screen (FriendsMatchScreen).
class RoomLobbyScreen extends StatelessWidget {
  const RoomLobbyScreen({super.key});

  // Hardcoded placeholder — real code generation comes in a later step.
  static const _kPlaceholderCode = 'ABCD12';

  void _showNextStep(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action — Coming Next Step'),
        backgroundColor: _kSurface,
        behavior: SnackBarBehavior.floating,
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
          'Room Lobby',
          style: TextStyle(
            color: _kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        iconTheme: const IconThemeData(color: _kTextSecondary),
        automaticallyImplyLeading: false, // Cancel button replaces back arrow
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Room Code card ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                color: _kSurface,
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Room Code',
                    style: TextStyle(
                      color: _kTextSecondary,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _kPlaceholderCode,
                    key: const Key('room_code_text'),
                    style: const TextStyle(
                      color: _kGold,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Copy / Share row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('copy_code_button'),
                          onPressed: () => _showNextStep(context, 'Copy Code'),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy Code'),
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('share_code_button'),
                          onPressed: () => _showNextStep(context, 'Share Code'),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share Code'),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // ── Waiting status ────────────────────────────────────────────
            const _WaitingIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Waiting for another player...',
              key: Key('waiting_status_text'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kTextSecondary,
                fontSize: 15,
                letterSpacing: 0.4,
              ),
            ),

            const Spacer(),

            // ── Cancel Room button ────────────────────────────────────────
            OutlinedButton(
              key: const Key('cancel_room_button'),
              onPressed: () {
                // Pop back to FriendsMatchScreen
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel Room'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Animated waiting indicator ───────────────────────────────────────────────

class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(_kPrimary),
        ),
      ),
    );
  }
}
