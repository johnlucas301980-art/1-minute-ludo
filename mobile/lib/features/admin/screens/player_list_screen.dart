import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../services/admin_service.dart';
import 'player_detail_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

const _kPageSize = 20;

/// Phase 10.2 — searchable, paginated list of all players.
///
/// Tap a row to open [PlayerDetailScreen] where the admin can ban / unban /
/// promote / demote the player.
class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key, required this.adminService});

  final AdminService adminService;

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  final _searchCtrl  = TextEditingController();
  final _scrollCtrl  = ScrollController();

  List<AdminUser> _users    = [];
  int             _total    = 0;
  int             _offset   = 0;
  bool            _loading  = true;
  bool            _loadingMore = false;
  String?         _error;
  String          _search   = '';

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
      setState(() { _loading = true; _error = null; _offset = 0; _users = []; });
    } else {
      setState(() { _loadingMore = true; });
    }

    try {
      final result = await widget.adminService.listUsers(
        limit:  _kPageSize,
        offset: reset ? 0 : _offset,
        search: _search.isEmpty ? null : _search,
      );

      if (!mounted) return;
      setState(() {
        _total = result.total;
        if (reset) {
          _users  = result.users;
          _offset = result.users.length;
        } else {
          _users.addAll(result.users);
          _offset += result.users.length;
        }
        _loading     = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error       = 'Failed to load players. Pull down to retry.';
        _loading     = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _users.length < _total) {
      _load();
    }
  }

  void _onSearchChanged(String value) {
    _search = value.trim();
    _load(reset: true);
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _openDetail(AdminUser user) async {
    final updated = await Navigator.push<AdminUser>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerDetailScreen(
          adminService: widget.adminService,
          userId: user.id,
        ),
      ),
    );

    // If the detail screen returned an updated user, refresh in the list.
    if (updated != null && mounted) {
      setState(() {
        _users = _users.map((u) => u.id == updated.id ? updated : u).toList();
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('player_list_screen'),
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Player Management'),
        backgroundColor: _kSurface,
        actions: [
          IconButton(
            key: const Key('refresh_button'),
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              key: const Key('search_field'),
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, email, player ID…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        key: const Key('clear_search_button'),
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: _kSurface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kPrimary),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // ── Total count ────────────────────────────────────────────────────
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  key: const Key('player_count'),
                  '$_total player${_total == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ),

          // ── List ───────────────────────────────────────────────────────────
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('players_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: _kPrimary,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _error!,
                  key: const Key('players_error'),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: _kPrimary,
        child: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No players found.',
                  key: Key('players_empty'),
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: _kPrimary,
      child: ListView.separated(
        key: const Key('players_list'),
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: _users.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == _users.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _kPrimary),
              ),
            );
          }
          return _PlayerRow(
            user: _users[i],
            onTap: () => _openDetail(_users[i]),
          );
        },
      ),
    );
  }
}

// ─── Row widget ───────────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.user, required this.onTap});
  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('player_row_${user.id}'),
      color: _kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _kPrimary.withOpacity(0.2),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.playerId,
              style: const TextStyle(color: _kGold, fontSize: 12),
            ),
            if (user.email != null)
              Text(
                user.email!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _RoleBadge(role: user.role),
            const SizedBox(height: 4),
            _StatusBadge(status: user.status),
          ],
        ),
      ),
    );
  }
}

// ─── Shared badges ────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final color   = isAdmin ? _kGold : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active'    => Colors.green,
      'suspended' => Colors.amber,
      'banned'    => Colors.red,
      _           => Colors.white54,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
