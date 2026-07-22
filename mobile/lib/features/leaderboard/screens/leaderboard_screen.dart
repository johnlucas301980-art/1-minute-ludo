import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/leaderboard.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

// ─── Dark arcade palette (consistent with HistoryScreen / WalletScreen) ───────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kRed           = Color(0xFFFF4C4C);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

// ─── LeaderboardScreen ────────────────────────────────────────────────────────

/// Displays the global leaderboard ranked by wins.
///
/// Manages four UI states — loading, error, empty, and data — with an
/// [AnimatedSwitcher] (280 ms) transitioning between them.
///
/// A [RefreshIndicator] on the data list allows pull-to-refresh.
///
/// [onSessionExpired] is called when a [SessionExpiredException] is caught;
/// the caller ([MainShell]) should clear the session and return to login.
///
/// All dependencies are injected through the constructor — no singletons.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.leaderboardService,
    required this.onSessionExpired,
  });

  final LeaderboardService leaderboardService;
  final VoidCallback        onSessionExpired;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Leaderboard? _leaderboard;
  bool         _loading = true;
  String?      _error;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      final leaderboard = await widget.leaderboardService.getLeaderboard();
      if (!mounted) return;
      setState(() {
        _leaderboard = leaderboard;
        _loading     = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      widget.onSessionExpired();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBg,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key:   Key('leaderboard_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return _ErrorView(
        key:     const Key('leaderboard_error'),
        message: _error!,
        onRetry: _loadData,
      );
    }

    if (_leaderboard == null || _leaderboard!.entries.isEmpty) {
      return const _EmptyView(key: Key('leaderboard_empty'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color:     _kPrimary,
      child: ListView.builder(
        key:         const Key('leaderboard_list'),
        padding:     const EdgeInsets.symmetric(vertical: 12),
        itemCount:   _leaderboard!.entries.length,
        itemBuilder: (context, index) => _LeaderboardTile(
          key:   Key('leaderboard_tile_$index'),
          entry: _leaderboard!.entries[index],
          index: index,
        ),
      ),
    );
  }
}

// ─── _ErrorView ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _kRed, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key:     const Key('leaderboard_retry'),
              onPressed: onRetry,
              style:   ElevatedButton.styleFrom(backgroundColor: _kPrimary),
              child:   const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _EmptyView ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard, color: _kGold, size: 64),
          SizedBox(height: 16),
          Text(
            'No players yet',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'The leaderboard will appear once matches are played.',
            style:     TextStyle(color: _kTextSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── _LeaderboardTile ─────────────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    super.key,
    required this.entry,
    required this.index,
  });

  final LeaderboardEntry entry;
  final int              index;

  @override
  Widget build(BuildContext context) {
    final isTopThree   = entry.rank <= 3;
    final rankColor    = isTopThree ? _kGold : _kTextSecondary;

    return Container(
      margin:     const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor.withValues(alpha: 0.15),
          child: Text(
            '#${entry.rank}',
            style: TextStyle(
              color:      rankColor,
              fontWeight: FontWeight.bold,
              fontSize:   13,
            ),
          ),
        ),
        title: Text(
          entry.fullName,
          style: const TextStyle(
            color:      Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          entry.playerId,
          style: const TextStyle(color: _kTextSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: _kGold, size: 16),
            const SizedBox(width: 4),
            Text(
              '${entry.wins}',
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.bold,
                fontSize:   15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
