import 'package:flutter/material.dart';

import '../models/admin_match.dart';
import '../services/admin_service.dart';
import 'match_details_screen.dart';

// ─── Palette (matches existing admin theme) ───────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

const _kPageSize = 20;

/// All valid match statuses for the filter dropdown.
const _kStatuses = ['waiting', 'in_progress', 'finished', 'cancelled'];

/// Phase 10.3 — searchable, filterable, paginated list of all matches.
///
/// Tap a row to open [MatchDetailsScreen] where an admin can view detail
/// and optionally cancel a waiting or in-progress match.
class MatchMonitorScreen extends StatefulWidget {
  const MatchMonitorScreen({super.key, required this.adminService});

  final AdminService adminService;

  @override
  State<MatchMonitorScreen> createState() => _MatchMonitorScreenState();
}

class _MatchMonitorScreenState extends State<MatchMonitorScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<AdminMatch> _matches    = [];
  int              _total      = 0;
  int              _offset     = 0;
  bool             _loading    = true;
  bool             _loadingMore = false;
  String?          _error;
  String           _search     = '';
  String?          _statusFilter;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error   = null;
        _offset  = 0;
        _matches = [];
      });
    } else {
      setState(() { _loadingMore = true; });
    }

    try {
      final result = await widget.adminService.getMatches(
        limit:  _kPageSize,
        offset: reset ? 0 : _offset,
        status: _statusFilter,
        search: _search.isEmpty ? null : _search,
      );
      if (!mounted) return;
      setState(() {
        _total = result.total;
        if (reset) {
          _matches = result.matches;
          _offset  = result.matches.length;
        } else {
          _matches.addAll(result.matches);
          _offset += result.matches.length;
        }
        _loading     = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error       = 'Failed to load matches. Pull down to retry.';
        _loading     = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _matches.length < _total) {
      _load();
    }
  }

  void _onSearchChanged(String value) {
    _search = value.trim();
    _load(reset: true);
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _openDetail(AdminMatch match) async {
    final updated = await Navigator.push<AdminMatch>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailsScreen(
          adminService: widget.adminService,
          matchId: match.id,
        ),
      ),
    );

    // If the detail screen returned an updated match (e.g. after cancel),
    // reflect the new status in the list without a full reload.
    if (updated != null && mounted) {
      setState(() {
        _matches = _matches
            .map((m) => m.id == updated.id ? updated : m)
            .toList();
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('match_monitor_screen'),
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Match Monitoring'),
        backgroundColor: _kSurface,
        actions: [
          IconButton(
            key: const Key('refresh_button'),
            icon: const Icon(Icons.refresh, color: _kGold),
            onPressed: () => _load(reset: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
          ),
          _FilterRow(
            selected: _statusFilter,
            onSelected: (s) {
              setState(() { _statusFilter = s; });
              _load(reset: true);
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('matches_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: () => _load(reset: true));
    }

    if (_matches.isEmpty) {
      return const Center(
        child: Text(
          key: Key('matches_empty'),
          'No matches found.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: _kPrimary,
      child: ListView.builder(
        key: const Key('match_list'),
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _matches.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _matches.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: _kPrimary),
              ),
            );
          }
          return _MatchTile(
            match: _matches[index],
            onTap: () => _openDetail(_matches[index]),
          );
        },
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        key: const Key('search_field'),
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search room code or player…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: _kSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kPrimary),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Filter row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});
  final String?            selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _FilterChip(
            key: const Key('filter_all'),
            label: 'All',
            active: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final s in _kStatuses)
            _FilterChip(
              key: Key('filter_$s'),
              label: s.replaceAll('_', ' '),
              active: selected == s,
              onTap: () => onSelected(s),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool   active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _kPrimary.withOpacity(0.2) : _kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? _kPrimary : _kBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? _kPrimary : Colors.white54,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Match tile ───────────────────────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onTap});
  final AdminMatch   match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('match_tile_${match.id}'),
      color: _kSurface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          match.roomCode,
                          style: const TextStyle(
                            color: _kGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: match.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.players.map((p) => p.fullName).join(' vs '),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmtDate(match.createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'waiting'     => Colors.blue,
      'in_progress' => Colors.green,
      'finished'    => Colors.purple,
      'cancelled'   => Colors.red,
      _             => Colors.white54,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String       message;
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
                key: const Key('matches_error'),
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
