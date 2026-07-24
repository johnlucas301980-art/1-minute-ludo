import 'package:flutter/material.dart';

import '../models/admin_report.dart';
import '../services/admin_service.dart';

const _kReportBg = Color(0xFF0D0D1A);
const _kReportSurface = Color(0xFF1A1A2E);
const _kReportPrimary = Color(0xFF6C63FF);
const _kReportGold = Color(0xFFFFD700);
const _kReportBorder = Color(0xFF2D2D4E);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.adminService});
  final AdminService adminService;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  AdminReport? _report;
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final report = await widget.adminService.getReport(
        from: _dateOnly(_from),
        to: _dateOnly(_to),
      );
      if (mounted) setState(() { _report = report; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load report.'; _loading = false; });
    }
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kReportPrimary,
            surface: _kReportSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (from) { _from = picked; } else { _to = picked; } });
    if (!_from.isBefore(_to)) {
      setState(() => _error = 'The start date must be before the end date.');
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('reports_screen'),
      backgroundColor: _kReportBg,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: _kReportSurface,
        actions: [
          IconButton(
            key: const Key('reports_refresh_button'),
            icon: const Icon(Icons.refresh, color: _kReportGold),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _DateRangeBar(from: _from, to: _to, onPick: _pickDate),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('report_loading'), color: _kReportPrimary),
      );
    }
    if (_error != null && _report == null) {
      return Center(child: Text(_error!, key: const Key('report_error'), style: const TextStyle(color: Colors.white70)));
    }
    final report = _report;
    if (report == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: _load,
      color: _kReportPrimary,
      child: ListView(
        key: const Key('report_list'),
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null) _InlineError(message: _error!),
          _ReportSection(
            title: 'Users',
            icon: Icons.people_outline,
            rows: {
              'Total': '${report.users.total}',
              'New in range': '${report.users.newUsers}',
              'Active': '${report.users.active}',
              'Suspended': '${report.users.suspended}',
              'Banned': '${report.users.banned}',
            },
          ),
          _ReportSection(
            title: 'Matches',
            icon: Icons.sports_esports_outlined,
            rows: {
              'Total': '${report.matches.total}',
              'Waiting': '${report.matches.waiting}',
              'In progress': '${report.matches.inProgress}',
              'Finished': '${report.matches.finished}',
              'Cancelled': '${report.matches.cancelled}',
            },
          ),
          _ReportSection(
            title: 'Wallets',
            icon: Icons.account_balance_wallet_outlined,
            rows: {
              'Wallets': '${report.wallets.walletCount}',
              'Points': report.wallets.totalPoints.toStringAsFixed(2),
              'Deposits': report.wallets.totalDeposit.toStringAsFixed(2),
              'Withdrawals': report.wallets.totalWithdraw.toStringAsFixed(2),
            },
          ),
          _ReportSection(
            title: 'Transactions',
            icon: Icons.receipt_long_outlined,
            rows: {
              'Total': '${report.transactions.total}',
              'Deposits': report.transactions.deposit.toStringAsFixed(2),
              'Withdrawals': report.transactions.withdraw.toStringAsFixed(2),
              'Rewards': report.transactions.reward.toStringAsFixed(2),
              'Entry fees': report.transactions.entryFee.toStringAsFixed(2),
              'Refunds': report.transactions.refund.toStringAsFixed(2),
            },
          ),
          _ReportSection(
            title: 'Support',
            icon: Icons.support_agent,
            rows: {
              'Open': '${report.support.open}',
              'In progress': '${report.support.inProgress}',
              'Resolved': '${report.support.resolved}',
              'Closed': '${report.support.closed}',
            },
          ),
        ],
      ),
    );
  }
}

class _DateRangeBar extends StatelessWidget {
  const _DateRangeBar({required this.from, required this.to, required this.onPick});
  final DateTime from;
  final DateTime to;
  final Future<void> Function(bool from) onPick;

  @override
  Widget build(BuildContext context) => Container(
        color: _kReportSurface,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(child: _DateButton(key: const Key('report_from_button'), label: 'From', value: from, onTap: () => onPick(true))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
            ),
            Expanded(child: _DateButton(key: const Key('report_to_button'), label: 'To', value: to, onTap: () => onPick(false))),
          ],
        ),
      );
}

class _DateButton extends StatelessWidget {
  const _DateButton({super.key, required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: _kReportBorder),
          alignment: Alignment.centerLeft,
        ),
        child: Text('$label: ${_dateOnly(value)}', style: const TextStyle(fontSize: 12)),
      );
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => Card(
        color: _kReportSurface,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _kReportBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: _kReportGold, size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(color: _kReportGold, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              for (final row in rows.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(row.key, style: const TextStyle(color: Colors.white70)),
                      Text(row.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(message, style: const TextStyle(color: Colors.orange)),
      );
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';