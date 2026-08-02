import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/login_history_entry.dart';
import '../services/login_history_service.dart';

// ─── Dark arcade palette (consistent with HistoryScreen / ProfileScreen) ──────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kRed           = Color(0xFFFF4C4C);
const _kGold          = Color(0xFFFFD700);

// ─── LoginHistoryScreen ───────────────────────────────────────────────────────

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({
    super.key,
    required this.loginHistoryService,
    required this.onSessionExpired,
  });

  final LoginHistoryService loginHistoryService;
  final VoidCallback         onSessionExpired;

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  List<LoginHistoryEntry>? _entries;
  bool    _loading = true;
  String? _error;

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
      final entries = await widget.loginHistoryService.getLoginHistory();
      if (!mounted) return;
      setState(() {
        _entries = entries;
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
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Login History',
          style: TextStyle(
            color:      Colors.white,
            fontWeight: FontWeight.bold,
            fontSize:   18,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key:   Key('login_history_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return _ErrorView(
        key:     const Key('login_history_error'),
        message: _error!,
        onRetry: _loadData,
      );
    }

    if (_entries == null || _entries!.isEmpty) {
      return const _EmptyView(key: Key('login_history_empty'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color:     _kPrimary,
      child: ListView.builder(
        key:         const Key('login_history_list'),
        padding:     const EdgeInsets.symmetric(vertical: 12),
        itemCount:   _entries!.length,
        itemBuilder: (context, index) => _LoginTile(
          key:   Key('login_tile_$index'),
          entry: _entries![index],
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
              key:     const Key('login_history_retry'),
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
          Icon(Icons.login, color: _kGold, size: 64),
          SizedBox(height: 16),
          Text(
            'No login history yet',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your login activity will appear here.',
            style:     TextStyle(color: _kTextSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── _LoginTile ───────────────────────────────────────────────────────────────

class _LoginTile extends StatelessWidget {
  const _LoginTile({
    super.key,
    required this.entry,
    required this.index,
  });

  final LoginHistoryEntry entry;
  final int               index;

  @override
  Widget build(BuildContext context) {
    final methodLabel = _methodLabel(entry.loginMethod);
    final methodIcon  = _methodIcon(entry.loginMethod);
    final dateStr     = _formatDate(entry.loginTime);

    return Container(
      margin:     const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          key:             Key('login_method_$index'),
          backgroundColor: _kPrimary.withOpacity(0.15),
          child:           Icon(methodIcon, color: _kPrimary, size: 20),
        ),
        title: Text(
          entry.deviceName ?? 'Unknown device',
          style: const TextStyle(
            color:      Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing:    8,
            runSpacing: 4,
            children: [
              _Chip(label: methodLabel),
              if (entry.platform != null)
                Text(
                  entry.platform!,
                  style: const TextStyle(
                    color:    _kTextSecondary,
                    fontSize: 12,
                  ),
                ),
              if (entry.country != null)
                Text(
                  entry.country!,
                  style: const TextStyle(
                    color:    _kTextSecondary,
                    fontSize: 12,
                  ),
                ),
              Text(
                dateStr,
                style: const TextStyle(
                  color:    _kTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'google': return 'Google';
      case 'mobile': return 'Mobile';
      default:       return 'Email';
    }
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'google': return Icons.g_mobiledata;
      case 'mobile': return Icons.phone_android;
      default:       return Icons.email_outlined;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt  = DateTime.parse(isoDate).toLocal();
      final y   = dt.year;
      final mo  = dt.month.toString().padLeft(2, '0');
      final d   = dt.day.toString().padLeft(2, '0');
      final h   = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y-$mo-$d $h:$min';
    } catch (_) {
      return isoDate;
    }
  }
}

// ─── _Chip ────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
