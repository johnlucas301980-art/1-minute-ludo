import 'package:flutter/material.dart';

import '../models/admin_stats.dart';
import '../models/admin_ticket.dart';
import '../models/admin_user.dart';
import '../models/audit_log_entry.dart';
import '../services/admin_service.dart';
import 'match_monitor_screen.dart';
import 'player_list_screen.dart';

// ─── Palette (matches existing app theme) ────────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

/// Admin dashboard screen — Phase 10.1 + 10.2 + 10.3.
///
/// Five tabs:
/// - **Stats**   — key platform metrics.
/// - **Players** — entry point to [PlayerListScreen] (Phase 10.2).
/// - **Matches** — match monitoring with cancel support (Phase 10.3).
/// - **Tickets** — all support tickets with status management.
/// - **Audit**   — admin action audit log (Phase 10.2).
///
/// Only reachable by users with role = 'admin'.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.adminService});

  final AdminService adminService;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('admin_screen'),
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: _kSurface,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kGold,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _kPrimary,
          tabs: const [
            Tab(key: Key('stats_tab'),   text: 'Stats'),
            Tab(key: Key('players_tab'), text: 'Players'),
            Tab(key: Key('matches_tab'), text: 'Matches'),
            Tab(key: Key('tickets_tab'), text: 'Tickets'),
            Tab(key: Key('audit_tab'),   text: 'Audit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StatsTab(adminService: widget.adminService),
          _PlayersTab(adminService: widget.adminService),
          _MatchesTab(adminService: widget.adminService),
          _TicketsTab(adminService: widget.adminService),
          _AuditTab(adminService: widget.adminService),
        ],
      ),
    );
  }
}

// ─── Stats tab ────────────────────────────────────────────────────────────────

class _StatsTab extends StatefulWidget {
  const _StatsTab({required this.adminService});
  final AdminService adminService;

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab>
    with AutomaticKeepAliveClientMixin {
  AdminStats? _stats;
  bool   _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await widget.adminService.getStats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load stats.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('stats_loading'), color: _kPrimary),
      );
    }

    if (_error != null) {
      return _ErrorView(message: _error!, widgetKey: const Key('stats_error'), onRetry: _load);
    }

    final s = _stats!;
    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView(
        key: const Key('stats_list'),
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Users'),
          _StatRow('Total',     s.totalUsers.toString()),
          _StatRow('Active',    s.activeUsers.toString()),
          _StatRow('Suspended', s.suspendedUsers.toString()),
          _StatRow('Banned',    s.bannedUsers.toString()),
          _StatRow('Admins',    s.adminUsers.toString()),
          const SizedBox(height: 16),
          _SectionHeader('Matches'),
          _StatRow('Total',       s.totalMatches.toString()),
          _StatRow('In Progress', s.inProgressMatches.toString()),
          const SizedBox(height: 16),
          _SectionHeader('Wallet'),
          _StatRow('Total Balance', s.totalWalletBalance.toStringAsFixed(2)),
          const SizedBox(height: 16),
          _SectionHeader('Support'),
          _StatRow('Open',        s.openTickets.toString()),
          _StatRow('In Progress', s.inProgressTickets.toString()),
        ],
      ),
    );
  }
}

// ─── Players tab (Phase 10.2) ─────────────────────────────────────────────────
// Navigates to PlayerListScreen so search/pagination live there.

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({required this.adminService});
  final AdminService adminService;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, color: _kPrimary, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Player Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search, view, ban/unban, and promote/demote players.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('open_player_list_button'),
              icon: const Icon(Icons.manage_accounts),
              label: const Text('Manage Players'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerListScreen(adminService: adminService),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Matches tab (Phase 10.3) ────────────────────────────────────────────────
// Entry-point tile that pushes MatchMonitorScreen.

class _MatchesTab extends StatelessWidget {
  const _MatchesTab({required this.adminService});
  final AdminService adminService;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_esports_outlined, color: _kPrimary, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Match Monitoring',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View all matches, filter by status, search by room code '
              'or player, and cancel active matches.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('open_match_monitor_button'),
              icon: const Icon(Icons.monitor_outlined),
              label: const Text('Open Match Monitor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MatchMonitorScreen(adminService: adminService),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tickets tab ──────────────────────────────────────────────────────────────

class _TicketsTab extends StatefulWidget {
  const _TicketsTab({required this.adminService});
  final AdminService adminService;

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab>
    with AutomaticKeepAliveClientMixin {
  List<AdminTicket>? _tickets;
  bool   _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.adminService.listTickets(limit: 50);
      if (mounted) setState(() { _tickets = result.tickets; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load tickets.'; _loading = false; });
    }
  }

  Future<void> _changeStatus(AdminTicket ticket, String newStatus) async {
    try {
      final updated = await widget.adminService.updateTicketStatus(ticket.id, newStatus);
      if (mounted) {
        setState(() {
          _tickets = _tickets?.map((t) => t.id == updated.id ? updated : t).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('tickets_loading'), color: _kPrimary),
      );
    }

    if (_error != null) {
      return _ErrorView(message: _error!, widgetKey: const Key('tickets_error'), onRetry: _load);
    }

    final tickets = _tickets ?? const [];
    if (tickets.isEmpty) {
      return const Center(
        child: Text('No tickets found.', key: Key('tickets_empty'), style: TextStyle(color: Colors.white70)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView.separated(
        key: const Key('tickets_list'),
        padding: const EdgeInsets.all(12),
        itemCount: tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _TicketTile(
          ticket: tickets[i],
          onChangeStatus: (status) => _changeStatus(tickets[i], status),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onChangeStatus});
  final AdminTicket ticket;
  final void Function(String status) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('ticket_tile_${ticket.id}'),
      color: _kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          ticket.subject,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ticket.fullName} (${ticket.playerId})',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Text(
              ticket.message.length > 80
                  ? '${ticket.message.substring(0, 80)}…'
                  : ticket.message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        trailing: _TicketStatusBadge(status: ticket.status),
        onLongPress: () => _showStatusSheet(context),
      ),
    );
  }

  void _showStatusSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Change ticket status',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            for (final s in ['open', 'in_progress', 'resolved', 'closed'])
              ListTile(
                key: Key('ticket_status_option_$s'),
                title: Text(s, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  onChangeStatus(s);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Audit log tab (Phase 10.2) ───────────────────────────────────────────────

class _AuditTab extends StatefulWidget {
  const _AuditTab({required this.adminService});
  final AdminService adminService;

  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab>
    with AutomaticKeepAliveClientMixin {
  List<AuditLogEntry>? _entries;
  bool    _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.adminService.getAuditLog(limit: 50);
      if (mounted) setState(() { _entries = result.entries; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load audit log.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('audit_loading'), color: _kPrimary),
      );
    }

    if (_error != null) {
      return _ErrorView(message: _error!, widgetKey: const Key('audit_error'), onRetry: _load);
    }

    final entries = _entries ?? const [];
    if (entries.isEmpty) {
      return const Center(
        child: Text('No audit entries yet.', key: Key('audit_empty'), style: TextStyle(color: Colors.white70)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView.separated(
        key: const Key('audit_list'),
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _AuditTile(entry: entries[i]),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});
  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.action) {
      'ban'                  => Colors.red,
      'unban'                => Colors.green,
      'promote'              => _kGold,
      'demote'               => Colors.orange,
      'status_change'        => Colors.blue,
      'role_change'          => Colors.purple,
      'ticket_status_change' => Colors.teal,
      _                      => Colors.white54,
    };

    return Card(
      key: Key('audit_tile_${entry.id}'),
      color: _kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(_actionIcon(entry.action), color: color),
        title: Text(
          entry.summary,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        subtitle: Text(
          'by ${entry.adminFullName} (${entry.adminPlayerId})\n${_fmtDate(entry.createdAt)}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _actionIcon(String action) => switch (action) {
    'ban'                  => Icons.block,
    'unban'                => Icons.check_circle_outline,
    'promote'              => Icons.arrow_upward,
    'demote'               => Icons.arrow_downward,
    'status_change'        => Icons.edit,
    'role_change'          => Icons.manage_accounts,
    'ticket_status_change' => Icons.support_agent,
    _                      => Icons.history,
  };
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: _kGold,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketStatusBadge extends StatelessWidget {
  const _TicketStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'open'        => Colors.blue,
      'in_progress' => Colors.amber,
      'resolved'    => Colors.green,
      'closed'      => Colors.grey,
      _             => Colors.white54,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.widgetKey,
    required this.onRetry,
  });
  final String    message;
  final Key       widgetKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      color: _kPrimary,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                message,
                key: widgetKey,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
