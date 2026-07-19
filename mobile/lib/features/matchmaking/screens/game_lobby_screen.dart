import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/game_started.dart';
import '../models/match_found.dart';
import '../models/room_ready.dart';
import '../services/game_lobby_service.dart';

// ─── Dark arcade palette (consistent with all existing screens) ───────────────
const _kBg           = Color(0xFF0D0D1A);
const _kSurface      = Color(0xFF1A1A2E);
const _kPrimary      = Color(0xFF6C63FF);
const _kGold         = Color(0xFFFFD700);
const _kBorder       = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kGreen        = Color(0xFF4CAF50);
const _kRed          = Color(0xFFFF4C4C);
const _kAmber        = Color(0xFFFFC107);

// ─── State enum ───────────────────────────────────────────────────────────────

enum _LobbyState { joining, waiting, ready, opponentLeft, error }

// ─── GameLobbyScreen ─────────────────────────────────────────────────────────

/// Pre-game waiting room — displayed after a match is found (Phase 5.3) and
/// before gameplay begins (Phase 6).
///
/// Lifecycle:
///  1. [joining]      — [GameLobbyService.joinRoom] is in flight.
///  2. [waiting]      — This player has joined; waiting for the opponent.
///  3. [ready]        — Both players have joined (`room_ready` received).
///                      The screen stays in this state until `game_start`
///                      arrives (~2.5 s later).
///  4. [opponentLeft] — Opponent disconnected before the room was ready.
///  5. [error]        — [GameLobbyException] was thrown by [joinRoom].
///
/// The screen never calls [Navigator] itself.  Routing is the parent's
/// responsibility via [onSessionExpired], [onLeaveRoom], and [onGameStart].
///
/// All dependencies are injected through the constructor —
/// no singletons or static references.
class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({
    super.key,
    required this.gameLobbyService,
    required this.matchFound,
    required this.onSessionExpired,
    required this.onLeaveRoom,
    required this.onGameStart,
  });

  final GameLobbyService gameLobbyService;

  /// The match data received from the `match_found` Socket.IO event.
  final MatchFound matchFound;

  /// Called when [GameLobbyService.joinRoom] throws [SessionExpiredException].
  /// The parent ([MainShell] → [AuthGate]) clears the session and routes to
  /// the login screen.
  final VoidCallback onSessionExpired;

  /// Called when the player taps Leave or when the opponent leaves and the
  /// player dismisses the screen.  The parent pops the route.
  final VoidCallback onLeaveRoom;

  /// Called when the `game_start` event is received from the server.
  /// The parent ([MainShell]) navigates to [GameScreen].
  final void Function(GameStarted gameStarted, MatchFound matchFound) onGameStart;

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  _LobbyState _state        = _LobbyState.joining;
  String?     _errorMessage;

  StreamSubscription<RoomReady>?   _roomReadySub;
  StreamSubscription<String>?      _opponentLeftSub;
  StreamSubscription<GameStarted>? _gameStartedSub;

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Subscribe to streams before emitting — avoids missing events on fast
    // servers where events fire before the first frame.
    _roomReadySub    = widget.gameLobbyService.onRoomReady.listen(_onRoomReady);
    _opponentLeftSub = widget.gameLobbyService.onOpponentLeft.listen(_onOpponentLeft);
    _gameStartedSub  = widget.gameLobbyService.onGameStart.listen(_onGameStarted);
    _joinRoom();
  }

  @override
  void dispose() {
    _roomReadySub?.cancel();
    _opponentLeftSub?.cancel();
    _gameStartedSub?.cancel();
    // Fire-and-forget — idempotent, safe to call when not in the room.
    widget.gameLobbyService.leaveRoom(widget.matchFound.matchId);
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _joinRoom() async {
    try {
      await widget.gameLobbyService.joinRoom(widget.matchFound.matchId);
      if (mounted) setState(() => _state = _LobbyState.waiting);
    } on SessionExpiredException {
      if (mounted) widget.onSessionExpired();
    } on GameLobbyException catch (e) {
      if (mounted) {
        setState(() {
          _state        = _LobbyState.error;
          _errorMessage = e.message;
        });
      }
    }
  }

  void _onRoomReady(RoomReady _) {
    if (mounted) setState(() => _state = _LobbyState.ready);
  }

  void _onOpponentLeft(String _) {
    if (mounted) setState(() => _state = _LobbyState.opponentLeft);
  }

  void _onGameStarted(GameStarted gameStarted) {
    if (mounted) {
      widget.onGameStart(gameStarted, widget.matchFound);
    }
  }

  void _leave() => widget.onLeaveRoom();

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        key: const Key('game_lobby_app_bar'),
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Game Lobby',
          style: TextStyle(
            color: _kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        leading: IconButton(
          key: const Key('leave_button'),
          icon: const Icon(Icons.arrow_back, color: _kTextSecondary),
          tooltip: 'Leave lobby',
          onPressed: _leave,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() => switch (_state) {
        _LobbyState.joining      => _buildJoining(),
        _LobbyState.waiting      => _buildWaiting(),
        _LobbyState.ready        => _buildReady(),
        _LobbyState.opponentLeft => _buildOpponentLeft(),
        _LobbyState.error        => _buildError(),
      };

  // ─── Joining view ─────────────────────────────────────────────────────────────

  Widget _buildJoining() {
    return const Center(
      key: Key('joining_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            key: Key('joining_spinner'),
            color: _kPrimary,
          ),
          SizedBox(height: 24),
          Text(
            'Joining game room\u2026',
            key: Key('joining_text'),
            style: TextStyle(color: _kTextSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ─── Waiting view ─────────────────────────────────────────────────────────────

  Widget _buildWaiting() {
    final match = widget.matchFound;
    return SingleChildScrollView(
      key: const Key('waiting_view'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MatchInfoCard(matchFound: match),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: _kAmber,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Waiting for opponent\u2026',
                key: Key('waiting_text'),
                style: TextStyle(color: _kAmber, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _LeaveButton(onPressed: _leave),
        ],
      ),
    );
  }

  // ─── Ready view ───────────────────────────────────────────────────────────────

  Widget _buildReady() {
    final match = widget.matchFound;
    return SingleChildScrollView(
      key: const Key('ready_view'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: _kGreen, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Room Ready!',
            key: Key('ready_text'),
            style: TextStyle(
              color: _kGreen,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Both players have joined.',
            key: Key('ready_subtitle'),
            style: TextStyle(color: _kTextSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _MatchInfoCard(matchFound: match),
          const SizedBox(height: 32),
          // Gameplay entry point — auto-triggered by game_start event
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('start_game_button'),
              onPressed: null, // Phase 6 will enable manual start if needed
              icon: const Icon(Icons.sports_esports),
              label: const Text(
                'STARTING SOON\u2026',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Opponent left view ───────────────────────────────────────────────────────

  Widget _buildOpponentLeft() {
    return Center(
      key: const Key('opponent_left_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('opponent_left_banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.15),
                border: Border.all(color: _kAmber.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_off_outlined, color: _kAmber, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Opponent left the lobby.',
                      key: Key('opponent_left_text'),
                      style: TextStyle(color: _kAmber, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _LeaveButton(onPressed: _leave),
          ],
        ),
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
                      _errorMessage ?? 'Failed to join the game room.',
                      key: const Key('error_message'),
                      style: const TextStyle(color: _kRed, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _LeaveButton(onPressed: _leave),
          ],
        ),
      ),
    );
  }
}

// ─── Private helper widgets ───────────────────────────────────────────────────

/// Card showing the opponent's info, assigned colour, and room code.
class _MatchInfoCard extends StatelessWidget {
  const _MatchInfoCard({required this.matchFound});

  final MatchFound matchFound;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('match_info_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _LobbyAvatar(
            fullName:  matchFound.opponent.fullName,
            avatarUrl: matchFound.opponent.avatar,
          ),
          const SizedBox(height: 12),
          Text(
            matchFound.opponent.fullName,
            key: const Key('opponent_name'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _LobbyColorChip(
            key: const Key('assigned_color'),
            color: matchFound.color,
          ),
          const SizedBox(height: 12),
          Text(
            'Room: ${matchFound.roomCode}',
            key: const Key('room_code'),
            style: const TextStyle(
              color: _kTextSecondary,
              fontSize: 13,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular avatar with gold ring and initials fallback.
class _LobbyAvatar extends StatelessWidget {
  const _LobbyAvatar({required this.fullName, this.avatarUrl});

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
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
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
class _LobbyColorChip extends StatelessWidget {
  const _LobbyColorChip({super.key, required this.color});

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

/// Shared "Leave Lobby" outlined button used across multiple lobby states.
class _LeaveButton extends StatelessWidget {
  const _LeaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('leave_lobby_button'),
        onPressed: onPressed,
        icon: const Icon(Icons.exit_to_app),
        label: const Text(
          'LEAVE LOBBY',
          style: TextStyle(letterSpacing: 1.2),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kTextSecondary,
          side: const BorderSide(color: _kBorder),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
