import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/match_found.dart';
import '../services/matchmaking_service.dart';

// ─── Dark arcade palette (consistent with all existing screens) ───────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface        = Color(0xFF1A1A2E);
const _kPrimary        = Color(0xFF6C63FF);
const _kGold           = Color(0xFFFFD700);
const _kBorder         = Color(0xFF2D2D4E);
const _kTextSecondary  = Color(0xFF9E9E9E);
const _kGreen          = Color(0xFF4CAF50);
const _kRed            = Color(0xFFFF4C4C);

// ─── State enum ───────────────────────────────────────────────────────────────

enum _SearchState { idle, searching, matchFound, error }

// ─── MatchmakingScreen ────────────────────────────────────────────────────────

/// Main matchmaking screen — replaces the [HomeScreen] placeholder.
///
/// Manages four visible states via an [AnimatedSwitcher]:
///
/// - **idle**       — "FIND MATCH" button.
/// - **searching**  — spinner + elapsed timer + "CANCEL" button.
/// - **matchFound** — opponent card, room code, colour chip, "PLAY" button.
/// - **error**      — error banner + "TRY AGAIN" button.
///
/// Queue join/leave happen exclusively via Socket.IO through [MatchmakingService].
/// No [Navigator] calls are made — routing is the parent's responsibility.
///
/// All dependencies are injected through the constructor —
/// no singletons or static references.
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({
    super.key,
    required this.matchmakingService,
    required this.onSessionExpired,
    required this.onMatchReady,
  });

  final MatchmakingService matchmakingService;

  /// Called when the socket connection is refused because the JWT has expired
  /// or is absent.  The parent ([MainShell] → [AuthGate]) is responsible for
  /// clearing the session and routing back to the login screen.
  final VoidCallback onSessionExpired;

  /// Called when the player taps PLAY after a match is found.  The parent
  /// ([MainShell]) is responsible for navigating to [GameLobbyScreen].
  final void Function(MatchFound match) onMatchReady;

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  _SearchState _state          = _SearchState.idle;
  MatchFound?  _matchFound;
  String?      _errorMessage;
  int          _elapsedSeconds = 0;
  Timer?       _elapsedTimer;
  StreamSubscription<MatchFound>? _matchSub;

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _matchSub = widget.matchmakingService.onMatchFound.listen(_onMatchFound);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _matchSub?.cancel();
    // Fire-and-forget — idempotent, safe to call when not queued.
    widget.matchmakingService.leaveQueue();
    super.dispose();
  }

  // ─── Matchmaking actions ─────────────────────────────────────────────────────

  Future<void> _startSearch() async {
    setState(() {
      _state          = _SearchState.searching;
      _elapsedSeconds = 0;
      _errorMessage   = null;
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    try {
      await widget.matchmakingService.joinQueue();
    } on SessionExpiredException {
      _elapsedTimer?.cancel();
      if (mounted) widget.onSessionExpired();
    } on MatchmakingException catch (e) {
      _elapsedTimer?.cancel();
      if (mounted) {
        setState(() {
          _state        = _SearchState.error;
          _errorMessage = e.message;
        });
      }
    }
  }

  Future<void> _cancelSearch() async {
    _elapsedTimer?.cancel();
    await widget.matchmakingService.leaveQueue();
    if (mounted) {
      setState(() {
        _state          = _SearchState.idle;
        _elapsedSeconds = 0;
      });
    }
  }

  void _onMatchFound(MatchFound event) {
    _elapsedTimer?.cancel();
    if (mounted) {
      setState(() {
        _state      = _SearchState.matchFound;
        _matchFound = event;
      });
    }
  }

  void _reset() {
    setState(() {
      _state      = _SearchState.idle;
      _matchFound = null;
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  static String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBg,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() => switch (_state) {
        _SearchState.idle       => _buildIdle(),
        _SearchState.searching  => _buildSearching(),
        _SearchState.matchFound => _buildMatchFound(),
        _SearchState.error      => _buildError(),
      };

  // ─── Idle view ───────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return Center(
      key: const Key('idle_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sports_esports,
              key: Key('home_icon'),
              color: _kGold,
              size: 72,
            ),
            const SizedBox(height: 24),
            const Text(
              '1 Minute Ludo',
              key: Key('home_title'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find your opponent',
              style: TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('find_match_button'),
                onPressed: _startSearch,
                icon: const Icon(Icons.search),
                label: const Text(
                  'FIND MATCH',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Searching view ───────────────────────────────────────────────────────────

  Widget _buildSearching() {
    return Center(
      key: const Key('searching_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _kPrimary),
            const SizedBox(height: 32),
            const Text(
              'Searching for opponent\u2026',
              key: Key('searching_text'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatElapsed(_elapsedSeconds),
              key: const Key('elapsed_time'),
              style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('cancel_button'),
                onPressed: _cancelSearch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kTextSecondary,
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Match Found view ─────────────────────────────────────────────────────────

  Widget _buildMatchFound() {
    final match = _matchFound!;
    return SingleChildScrollView(
      key: const Key('match_found_view'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: _kGold, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Match Found!',
            key: Key('match_found_text'),
            style: TextStyle(
              color: _kGold,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          // Opponent card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _OpponentAvatar(
                  fullName:  match.opponent.fullName,
                  avatarUrl: match.opponent.avatar,
                ),
                const SizedBox(height: 12),
                Text(
                  match.opponent.fullName,
                  key: const Key('opponent_name'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _ColorChip(
                  key: const Key('match_color'),
                  color: match.color,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Room: ${match.roomCode}',
            key: const Key('room_code'),
            style: const TextStyle(
              color: _kTextSecondary,
              fontSize: 14,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('play_button'),
              onPressed: () {
                final match = _matchFound!;
                _reset();
                widget.onMatchReady(match);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'PLAY',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error view ───────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      key: const Key('error_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error banner
            Container(
              key: const Key('error_banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.15),
                border: Border.all(color: _kRed.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: _kRed, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage ??
                          'Matchmaking failed. Please try again.',
                      style: const TextStyle(color: _kRed, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('retry_button'),
                onPressed: () => setState(() {
                  _state        = _SearchState.idle;
                  _errorMessage = null;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'TRY AGAIN',
                  style: TextStyle(letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Private helper widgets ───────────────────────────────────────────────────

/// Circular avatar with gold ring and initials fallback.
/// Used inside the Match Found opponent card.
class _OpponentAvatar extends StatelessWidget {
  const _OpponentAvatar({required this.fullName, this.avatarUrl});

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
      radius: 32,
      backgroundColor: _kPrimary,
      backgroundImage:
          avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

/// Colour pill chip showing the player's assigned Ludo board colour.
class _ColorChip extends StatelessWidget {
  const _ColorChip({super.key, required this.color});

  final String color;

  static Color _toFlutterColor(String name) => switch (name) {
        'red'    => const Color(0xFFFF4C4C),
        'blue'   => const Color(0xFF4C8EFF),
        'green'  => const Color(0xFF4CAF50),
        'yellow' => const Color(0xFFFFC107),
        _        => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final chipColor = _toFlutterColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.2),
        border: Border.all(color: chipColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        color.toUpperCase(),
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
