// STEP 1 - REAL MATCHMAKING ARCHITECTURE
// BOT FALLBACK WILL BE IMPLEMENTED IN STEP 2

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/online_matchmaking_service.dart';

// ─── Dark arcade palette (matches app theme) ──────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Searching Players screen — shows a 60-second countdown while polling the
/// [OnlineMatchmakingService] once per second for real opponents.
///
/// When [OnlineMatchmakingService.checkForPlayers] returns
/// [MatchCheckResult.found]:
///  1. The countdown and polling stop immediately.
///  2. A "Match Found!" overlay is shown.
///  3. The user is navigated to the game-starting screen.
///
/// If 60 seconds elapse without a match, the countdown stops at 0 and the
/// screen remains visible — bot fallback will be implemented in STEP 2.
///
/// The [matchmakingService] parameter is optional; when omitted,
/// [SimulatedOnlineMatchmakingService] is used automatically so that
/// [GameSetupLobbyScreen] does not need to be changed.
class SearchingPlayersScreen extends StatefulWidget {
  const SearchingPlayersScreen({
    super.key,
    required this.players,
    required this.entryPoints,
    required this.pawnCount,
    required this.boardColor,
    this.matchmakingService,
  });

  final int    players;
  final int    entryPoints;
  final int    pawnCount;
  final String boardColor;

  /// Injectable matchmaking service.  Defaults to
  /// [SimulatedOnlineMatchmakingService] when null.
  final OnlineMatchmakingService? matchmakingService;

  @override
  State<SearchingPlayersScreen> createState() =>
      _SearchingPlayersScreenState();
}

class _SearchingPlayersScreenState extends State<SearchingPlayersScreen>
    with SingleTickerProviderStateMixin {
  static const _kDuration = 60;

  int    _secondsLeft  = _kDuration;
  bool   _matchFound   = false;
  Timer? _timer;

  late final AnimationController _pulseController;
  late final Animation<double>   _pulseAnimation;
  late final OnlineMatchmakingService _matchmakingService;

  @override
  void initState() {
    super.initState();

    // Use injected service or fall back to the simulated implementation.
    _matchmakingService =
        widget.matchmakingService ?? SimulatedOnlineMatchmakingService();

    // Pulsing ring animation.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Every second: decrement the countdown AND poll the matchmaking service.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    // Only dispose if we created the service ourselves (i.e. it was not
    // injected by the caller).
    if (widget.matchmakingService == null) {
      _matchmakingService.dispose();
    }
    super.dispose();
  }

  // ─── Tick: countdown + service poll ──────────────────────────────────────

  Future<void> _tick() async {
    if (_matchFound) return; // Already handled — ignore late callbacks.

    // Poll the matchmaking service first so a match found on the final second
    // is still detected.
    final result = await _matchmakingService.checkForPlayers(
      players:     widget.players,
      entryPoints: widget.entryPoints,
      pawnCount:   widget.pawnCount,
      boardColor:  widget.boardColor,
    );

    if (!mounted) return;

    if (result == MatchCheckResult.found) {
      _onMatchFound();
      return;
    }

    // Decrement countdown (stop at 0).
    if (_secondsLeft > 0) {
      setState(() => _secondsLeft--);
    } else {
      // 60 seconds elapsed — no match yet.
      // BOT FALLBACK WILL BE IMPLEMENTED IN STEP 2.
      _timer?.cancel();
    }
  }

  // ─── Match found ──────────────────────────────────────────────────────────

  void _onMatchFound() {
    _timer?.cancel();
    setState(() => _matchFound = true);

    // Brief pause so the "Match Found!" state is visible before navigating.
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const _GameStartingPlaceholder(),
        ),
      );
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          _matchFound ? 'Match Found!' : 'Finding Players...',
          style: TextStyle(
            color: _matchFound ? const Color(0xFF4CAF50) : _kGold,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: _matchFound ? _buildMatchFoundBody() : _buildSearchingBody(),
        ),
      ),
    );
  }

  // ─── Searching body ───────────────────────────────────────────────────────

  Widget _buildSearchingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),

        // ── Animated ring + countdown ───────────────────────────────────
        Center(
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
                      value: _secondsLeft > 0
                          ? _secondsLeft / _kDuration
                          : 0,
                    ),
                  ),
                  Text(
                    '$_secondsLeft',
                    key: const Key('countdown_timer'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Center(
          child: Text(
            'Searching for opponents...',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 15,
              letterSpacing: 0.4,
            ),
          ),
        ),

        const Spacer(),

        // ── Divider ─────────────────────────────────────────────────────
        Container(height: 1, color: _kBorder),
        const SizedBox(height: 24),

        // ── Selected settings ────────────────────────────────────────────
        const Text(
          'MATCH SETTINGS',
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _SettingRow(
          icon: Icons.group_outlined,
          label: 'Players',
          value: '${widget.players}',
        ),
        const SizedBox(height: 10),
        _SettingRow(
          icon: Icons.stars_outlined,
          label: 'Entry Points',
          value: '${widget.entryPoints}',
        ),
        const SizedBox(height: 10),
        _SettingRow(
          icon: Icons.circle_outlined,
          label: 'Pawn Count',
          value: '${widget.pawnCount}',
        ),
        const SizedBox(height: 10),
        _SettingRow(
          icon: Icons.palette_outlined,
          label: 'Board Color',
          value: widget.boardColor,
          valueColor: _boardFlutterColor(widget.boardColor),
        ),
        const SizedBox(height: 32),

        // ── Cancel button ────────────────────────────────────────────────
        OutlinedButton(
          key: const Key('cancel_search_button'),
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kTextSecondary,
            side: const BorderSide(color: _kBorder),
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
          child: const Text('Cancel'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Match found body ─────────────────────────────────────────────────────

  Widget _buildMatchFoundBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle,
          key: Key('match_found_icon'),
          color: Color(0xFF4CAF50),
          size: 96,
        ),
        const SizedBox(height: 24),
        const Text(
          'Match Found!',
          key: Key('match_found_text'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF4CAF50),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Starting game...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 15,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ─── Game Starting placeholder ────────────────────────────────────────────────
// Temporary screen shown after match found until full GameScreen wiring is
// completed in a future step.

class _GameStartingPlaceholder extends StatelessWidget {
  const _GameStartingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Game Starting...',
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
      body: const Center(
        child: Text(
          'Game Starting...',
          key: Key('game_starting_text'),
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 18,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _boardFlutterColor(String name) => switch (name) {
      'Red'    => const Color(0xFFFF4C4C),
      'Yellow' => const Color(0xFFFFC107),
      'Green'  => const Color(0xFF4CAF50),
      'Blue'   => const Color(0xFF4C8EFF),
      _        => const Color(0xFF9E9E9E),
    };

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
