import 'package:flutter/material.dart';

import '../models/admin_match.dart';
import '../services/admin_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

/// Phase 10.3 — full match detail for admins.
///
/// Shows match metadata, player roster, and a derived events timeline.
/// When the match is in a cancellable state (waiting / in_progress) a
/// CANCEL MATCH button is shown behind a confirmation dialog.
///
/// Pops with the updated [AdminMatch] after a successful cancel so the
/// caller (MatchMonitorScreen) can refresh its list entry.
class MatchDetailsScreen extends StatefulWidget {
  const MatchDetailsScreen({
    super.key,
    required this.adminService,
    required this.matchId,
  });

  final AdminService adminService;
  final String       matchId;

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  AdminMatch?            _match;
  List<AdminMatchEvent>  _events    = [];
  bool                   _loading   = true;
  String?                _error;
  bool                   _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.adminService.getMatchById(widget.matchId),
        widget.adminService.getMatchEvents(widget.matchId),
      ]);

      if (!mounted) return;
      final match  = results[0] as AdminMatch?;
      final events = results[1] as List<AdminMatchEvent>;

      if (match == null) {
        setState(() { _error = 'Match not found.'; _loading = false; });
      } else {
        setState(() { _match = match; _events = events; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load match.'; _loading = false; });
    }
  }

  // ── Cancel action ────────────────────────────────────────────────────────────

  Future<void> _cancelMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('cancel_confirm_dialog'),
        backgroundColor: _kSurface,
        title: const Text(
          'Cancel Match',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to cancel match ${_match!.roomCode}? '
          'This action is recorded in the audit log.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            key: const Key('cancel_dialog_dismiss'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            key: const Key('confirm_cancel_match'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Match'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() { _cancelling = true; });
    try {
      final updated = await widget.adminService.cancelMatch(widget.matchId);
      if (!mounted) return;
      setState(() { _match = updated; _cancelling = false; });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match cancelled successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Pop back with the updated match so the list can refresh the row.
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() { _cancelling = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^.*?: '), ''),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('match_details_screen'),
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(_match?.roomCode ?? 'Match Details'),
        backgroundColor: _kSurface,
        actions: [
          IconButton(
            key: const Key('refresh_button'),
            icon: const Icon(Icons.refresh, color: _kGold),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('match_details_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          key: const Key('match_details_error'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final m = _match!;
    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Match Info',
            child: Column(
              children: [
                _InfoRow('Room Code', m.roomCode,
                    valueStyle: const TextStyle(
                      color: _kGold,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    )),
                _InfoRow('Status', m.status.replaceAll('_', ' ')),
                _InfoRow('Mode', m.mode),
                _InfoRow('Entry Points', m.entryPoints.toStringAsFixed(2)),
                _InfoRow('Created', _fmtDate(m.createdAt)),
                if (m.startedAt != null)
                  _InfoRow('Started', _fmtDate(m.startedAt!)),
                if (m.finishedAt != null)
                  _InfoRow('Finished', _fmtDate(m.finishedAt!)),
                if (m.winnerFullName != null)
                  _InfoRow('Winner', '${m.winnerFullName} (${m.winnerPlayerId})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Players',
            child: m.players.isEmpty
                ? const Text(
                    'No players joined.',
                    key: Key('no_players'),
                    style: TextStyle(color: Colors.white54),
                  )
                : Column(
                    children: m.players
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                _ColorDot(color: p.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.fullName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        p.playerId,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (m.winnerId == p.userId)
                                  const Icon(Icons.emoji_events,
                                      color: _kGold, size: 18),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Timeline',
              child: Column(
                children: _events
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                const Icon(Icons.circle,
                                    size: 8, color: _kPrimary),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: _kBorder,
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.description,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _fmtDate(e.timestamp),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (m.isCancellable) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const Key('cancel_match_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _cancelling ? null : _cancelMatch,
              icon: _cancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        key: Key('cancel_spinner'),
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(_cancelling ? 'Cancelling…' : 'Cancel Match'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _kGold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const Divider(color: _kBorder, height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.valueStyle});
  final String     label;
  final String     value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Color dot ────────────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final String color;

  @override
  Widget build(BuildContext context) {
    final c = switch (color) {
      'red'    => Colors.red,
      'blue'   => Colors.blue,
      'green'  => Colors.green,
      'yellow' => Colors.yellow,
      _        => Colors.white38,
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
