import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../services/admin_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

/// Phase 10.2 — full player profile for admins.
///
/// Shows all user details and exposes ban / unban / promote / demote actions,
/// each behind a confirmation dialog. After a successful action the screen
/// pops with the updated [AdminUser] so the caller can refresh its list.
class PlayerDetailScreen extends StatefulWidget {
  const PlayerDetailScreen({
    super.key,
    required this.adminService,
    required this.userId,
  });

  final AdminService adminService;
  final String       userId;

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  AdminUser? _user;
  bool       _loading = true;
  String?    _error;
  bool       _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = await widget.adminService.getUserById(widget.userId);
      if (!mounted) return;
      if (user == null) {
        setState(() { _error = 'Player not found.'; _loading = false; });
      } else {
        setState(() { _user = user; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load player.'; _loading = false; });
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _runAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Color  confirmColor,
    required Future<AdminUser> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            key: Key('confirm_${confirmLabel.toLowerCase().replaceAll(' ', '_')}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() { _actionInProgress = true; });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() { _user = updated; _actionInProgress = false; });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title successful.'),
          backgroundColor: Colors.green.shade800,
        ),
      );

      // Pop the screen back with the updated user so the list refreshes.
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() { _actionInProgress = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString().replaceFirst(RegExp(r'^.*?: '), '')}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _ban() => _runAction(
    title:        'Ban Player',
    message:      'Are you sure you want to ban ${_user!.fullName}? They will be unable to log in.',
    confirmLabel: 'Ban',
    confirmColor: Colors.red,
    action:       () => widget.adminService.banUser(_user!.id),
  );

  void _unban() => _runAction(
    title:        'Unban Player',
    message:      'Are you sure you want to unban ${_user!.fullName}? They will regain access.',
    confirmLabel: 'Unban',
    confirmColor: Colors.green,
    action:       () => widget.adminService.unbanUser(_user!.id),
  );

  void _promote() => _runAction(
    title:        'Promote to Admin',
    message:      'Grant admin privileges to ${_user!.fullName}? They will have full admin access.',
    confirmLabel: 'Promote',
    confirmColor: _kGold,
    action:       () => widget.adminService.promoteUser(_user!.id),
  );

  void _demote() => _runAction(
    title:        'Demote to Player',
    message:      'Remove admin privileges from ${_user!.fullName}?',
    confirmLabel: 'Demote',
    confirmColor: Colors.orange,
    action:       () => widget.adminService.demoteUser(_user!.id),
  );

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('player_detail_screen'),
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(_user?.fullName ?? 'Player Details'),
        backgroundColor: _kSurface,
        actions: [
          IconButton(
            key: const Key('detail_refresh_button'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
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
          key: Key('detail_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                key: const Key('detail_error'),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Identity ───────────────────────────────────────────────────
            _Section(
              title: 'Identity',
              children: [
                _DetailRow('Full name',  user.fullName),
                _DetailRow('Player ID',  user.playerId, highlight: true),
                if (user.email  != null) _DetailRow('Email',   user.email!),
                if (user.mobile != null) _DetailRow('Mobile',  user.mobile!),
                if (user.country != null) _DetailRow('Country', user.country!),
              ],
            ),
            const SizedBox(height: 16),

            // ── Account ────────────────────────────────────────────────────
            _Section(
              title: 'Account',
              children: [
                _BadgeRow('Role',   _RoleBadgeWidget(role: user.role)),
                _BadgeRow('Status', _StatusBadgeWidget(status: user.status)),
                _DetailRow('Verified', user.isVerified ? 'Yes' : 'No'),
                _DetailRow('Joined',   _fmtDate(user.createdAt)),
                if (user.lastLoginAt != null)
                  _DetailRow('Last login', _fmtDate(user.lastLoginAt!)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Actions ────────────────────────────────────────────────────
            _Section(
              title: 'Actions',
              children: [
                const SizedBox(height: 8),
                _ActionButtons(
                  user:            user,
                  actionInProgress: _actionInProgress,
                  onBan:     _ban,
                  onUnban:   _unban,
                  onPromote: _promote,
                  onDemote:  _demote,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),

        if (_actionInProgress)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(
                key: Key('action_spinner'),
                color: _kPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.user,
    required this.actionInProgress,
    required this.onBan,
    required this.onUnban,
    required this.onPromote,
    required this.onDemote,
  });

  final AdminUser user;
  final bool      actionInProgress;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onPromote;
  final VoidCallback onDemote;

  @override
  Widget build(BuildContext context) {
    final isBanned  = user.status == 'banned';
    final isAdmin   = user.role   == 'admin';
    final disabled  = actionInProgress;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Ban / Unban
        if (!isBanned)
          ElevatedButton.icon(
            key: const Key('ban_button'),
            onPressed: disabled ? null : onBan,
            icon: const Icon(Icons.block),
            label: const Text('Ban'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          )
        else
          ElevatedButton.icon(
            key: const Key('unban_button'),
            onPressed: disabled ? null : onUnban,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Unban'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),

        // Promote / Demote
        if (!isAdmin)
          ElevatedButton.icon(
            key: const Key('promote_button'),
            onPressed: disabled ? null : onPromote,
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Promote to Admin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          )
        else
          ElevatedButton.icon(
            key: const Key('demote_button'),
            onPressed: disabled ? null : onDemote,
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Demote to Player'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String        title;
  final List<Widget>  children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: _kGold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool   highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? _kGold : Colors.white,
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow(this.label, this.badge);
  final String label;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          badge,
        ],
      ),
    );
  }
}

class _RoleBadgeWidget extends StatelessWidget {
  const _RoleBadgeWidget({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final color   = isAdmin ? _kGold : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatusBadgeWidget extends StatelessWidget {
  const _StatusBadgeWidget({required this.status});
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
