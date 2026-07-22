import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/match_history.dart';
import '../models/match_history_entry.dart';
import '../services/history_service.dart';

// ─── Dark arcade palette (consistent with WalletScreen / ProfileScreen) ───────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kGreen         = Color(0xFF4CAF50);
const _kRed           = Color(0xFFFF4C4C);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

// ─── HistoryScreen ────────────────────────────────────────────────────────────

/// Displays the authenticated player's completed match history.
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
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.historyService,
    required this.onSessionExpired,
  });

  final HistoryService historyService;
  final VoidCallback   onSessionExpired;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  MatchHistory? _history;
  bool          _loading = true;
  String?       _error;

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
      final history = await widget.historyService.getHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
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
          key: Key('history_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return _ErrorView(
        key: const Key('history_error'),
        message: _error!,
        onRetry: _loadData,
      );
    }

    if (_history == null || _history!.entries.isEmpty) {
      return const _EmptyHistoryView(key: Key('history_empty'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _kPrimary,
      child: ListView.builder(
        key: const Key('history_list'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _history!.entries.length,
        itemBuilder: (context, index) => _MatchTile(
          key:   Key('match_tile_$index'),
          entry: _history!.entries[index],
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
              key: const Key('history_retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _EmptyHistoryView ────────────────────────────────────────────────────────

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, color: _kGold, size: 64),
          SizedBox(height: 16),
          Text(
            'No matches yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your completed matches will appear here.',
            style: TextStyle(color: _kTextSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── _MatchTile ───────────────────────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    super.key,
    required this.entry,
    required this.index,
  });

  final MatchHistoryEntry entry;
  final int               index;

  @override
  Widget build(BuildContext context) {
    final isWin       = entry.result == 'win';
    final resultColor = isWin ? _kGreen : _kRed;
    final resultIcon  = isWin ? Icons.check : Icons.close;
    final pointsSign  = entry.earnedPoints >= 0 ? '+' : '';
    final modeLabel   = entry.mode == 'friend' ? 'Friend' : 'Random';
    final dateStr     = _formatDate(entry.finishedAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          key:             Key('match_result_$index'),
          backgroundColor: resultColor.withOpacity(0.15),
          child:           Icon(resultIcon, color: resultColor, size: 20),
        ),
        title: Text(
          entry.opponent.fullName,
          style: const TextStyle(
            color:      Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _ModeChip(label: modeLabel),
              Text(
                entry.roomCode,
                style: const TextStyle(color: _kTextSecondary, fontSize: 12),
              ),
              if (dateStr != null)
                Text(
                  dateStr,
                  style: const TextStyle(color: _kTextSecondary, fontSize: 12),
                ),
            ],
          ),
        ),
        trailing: Text(
          '$pointsSign${entry.earnedPoints.toStringAsFixed(1)}',
          style: TextStyle(
            color:      isWin ? _kGreen : _kRed,
            fontWeight: FontWeight.bold,
            fontSize:   15,
          ),
        ),
      ),
    );
  }

  /// Parses an ISO-8601 timestamp and returns a human-readable local time
  /// string (`YYYY-MM-DD HH:MM`).  Returns `null` if the input is null;
  /// returns the raw string if parsing fails.
  String? _formatDate(String? isoDate) {
    if (isoDate == null) return null;
    try {
      final dt  = DateTime.parse(isoDate).toLocal();
      final y   = dt.year;
      final m   = dt.month.toString().padLeft(2, '0');
      final d   = dt.day.toString().padLeft(2, '0');
      final h   = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min';
    } catch (_) {
      return isoDate;
    }
  }
}

// ─── _ModeChip ────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:        _kPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _kPrimary.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: _kPrimary, fontSize: 11),
      ),
    );
  }
}
