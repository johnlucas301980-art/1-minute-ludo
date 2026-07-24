import 'package:flutter/material.dart';

import '../models/admin_wallet.dart';
import '../services/admin_service.dart';

const _kWalletBg = Color(0xFF0D0D1A);
const _kWalletSurface = Color(0xFF1A1A2E);
const _kWalletPrimary = Color(0xFF6C63FF);
const _kWalletGold = Color(0xFFFFD700);
const _kWalletBorder = Color(0xFF2D2D4E);

class WalletMonitoringScreen extends StatefulWidget {
  const WalletMonitoringScreen({super.key, required this.adminService});

  final AdminService adminService;

  @override
  State<WalletMonitoringScreen> createState() => _WalletMonitoringScreenState();
}

class _WalletMonitoringScreenState extends State<WalletMonitoringScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<AdminWallet> _wallets = [];
  int _total = 0;
  int _offset = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _offset = 0;
        _wallets = [];
        _error = null;
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final result = await widget.adminService.listWallets(
        limit: 20,
        offset: reset ? 0 : _offset,
        search: _search.isEmpty ? null : _search,
      );
      if (!mounted) return;
      setState(() {
        _wallets = reset ? result.wallets : [..._wallets, ...result.wallets];
        _offset = reset ? result.wallets.length : _offset + result.wallets.length;
        _total = result.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Failed to load wallet records. Pull down to retry.';
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 180 &&
        !_loadingMore &&
        _wallets.length < _total) {
      _load();
    }
  }

  void _onSearchChanged(String value) {
    _search = value.trim();
    _load(reset: true);
  }

  Future<void> _openTransactions(AdminWallet wallet) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kWalletSurface,
      isScrollControlled: true,
      builder: (_) => _WalletTransactionsSheet(
        adminService: widget.adminService,
        wallet: wallet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('wallet_monitoring_screen'),
      backgroundColor: _kWalletBg,
      appBar: AppBar(
        title: const Text('Wallet Monitoring'),
        backgroundColor: _kWalletSurface,
        actions: [
          IconButton(
            key: const Key('wallet_refresh_button'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: _kWalletGold),
            onPressed: () => _load(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              key: const Key('wallet_search_field'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search player, email, or wallet…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: _kWalletSurface,
                border: _border(),
                enabledBorder: _border(),
                focusedBorder: _border(_kWalletPrimary),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  OutlineInputBorder _border([Color color = _kWalletBorder]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('wallets_loading'),
          color: _kWalletPrimary,
        ),
      );
    }
    if (_error != null) {
      return _RetryView(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_wallets.isEmpty) {
      return const Center(
        child: Text(
          'No wallet records found.',
          key: Key('wallets_empty'),
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: _kWalletPrimary,
      child: ListView.builder(
        key: const Key('wallet_list'),
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _wallets.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index >= _wallets.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: _kWalletPrimary),
              ),
            );
          }
          final wallet = _wallets[index];
          return Card(
            key: Key('wallet_tile_${wallet.walletId}'),
            color: _kWalletSurface,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: _kWalletBorder),
            ),
            child: ListTile(
              onTap: () => _openTransactions(wallet),
              leading: CircleAvatar(
                backgroundColor: _kWalletPrimary.withOpacity(.2),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _kWalletGold,
                ),
              ),
              title: Text(
                wallet.fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${wallet.playerId} • ${wallet.transactionCount} transactions\n'
                'Deposited ${wallet.totalDeposit.toStringAsFixed(2)} • '
                'Withdrawn ${wallet.totalWithdraw.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              isThreeLine: true,
              trailing: Text(
                wallet.points.toStringAsFixed(2),
                style: const TextStyle(
                  color: _kWalletGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WalletTransactionsSheet extends StatefulWidget {
  const _WalletTransactionsSheet({
    required this.adminService,
    required this.wallet,
  });

  final AdminService adminService;
  final AdminWallet wallet;

  @override
  State<_WalletTransactionsSheet> createState() =>
      _WalletTransactionsSheetState();
}

class _WalletTransactionsSheetState extends State<_WalletTransactionsSheet> {
  bool _loading = true;
  String? _error;
  List<AdminWalletTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.adminService.listWalletTransactions(
        widget.wallet.userId,
        limit: 50,
      );
      if (mounted) setState(() { _transactions = result.transactions; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load transactions.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            ListTile(
              title: Text(
                '${widget.wallet.fullName} transactions',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(widget.wallet.playerId, style: const TextStyle(color: Colors.white54)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kWalletPrimary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
                      : _transactions.isEmpty
                          ? const Center(child: Text('No transactions.', style: TextStyle(color: Colors.white54)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _transactions.length,
                              separatorBuilder: (_, __) => const Divider(color: _kWalletBorder),
                              itemBuilder: (_, index) {
                                final tx = _transactions[index];
                                return ListTile(
                                  title: Text(
                                    tx.type.replaceAll('_', ' '),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '${_formatDate(tx.createdAt)}${tx.reference == null ? '' : '\n${tx.reference}'}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  trailing: Text(
                                    tx.amount.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: tx.type == 'withdraw' ? Colors.orange : Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => onRetry(),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                message,
                key: const Key('wallets_error'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
}

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';