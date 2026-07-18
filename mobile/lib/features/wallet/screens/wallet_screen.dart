import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';

// ─── Dark arcade palette (consistent with ProfileScreen) ─────────────────────
const _kBg = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold = Color(0xFFFFD700);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFFF4C4C);
const _kAmber = Color(0xFFFFC107);

// ─── WalletScreen ─────────────────────────────────────────────────────────────

/// Displays the authenticated player's wallet balance and transaction history.
///
/// Manages three states — loading, error, and data — with a pull-to-refresh
/// gesture to reload both from the server.
///
/// All service dependencies are injected through the constructor — no
/// singletons or static references.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.walletService});

  final WalletService walletService;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Wallet? _wallet;
  WalletHistory? _history;
  bool _loading = true;
  String? _error;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.walletService.getWallet(),
        widget.walletService.getHistory(),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as Wallet;
          _history = results[1] as WalletHistory;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to the server. Please try again.';
          _loading = false;
        });
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: _kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _LoadingView(key: ValueKey('loading'));
    if (_error != null) {
      return _ErrorView(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: _loadData,
      );
    }
    return _WalletView(
      key: const ValueKey('wallet'),
      wallet: _wallet!,
      history: _history!,
      onRefresh: _loadData,
    );
  }
}

// ─── Loading view ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _kPrimary),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 60,
              color: _kTextSecondary,
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not load wallet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wallet view ──────────────────────────────────────────────────────────────

class _WalletView extends StatelessWidget {
  const _WalletView({
    super.key,
    required this.wallet,
    required this.history,
    required this.onRefresh,
  });

  final Wallet wallet;
  final WalletHistory history;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kPrimary,
      backgroundColor: _kSurface,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Balance card ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _BalanceCard(wallet: wallet),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Section header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'TRANSACTION HISTORY',
                    style: TextStyle(
                      color: _kTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  if (history.total > 0)
                    Text(
                      '${history.total} record${history.total == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Transaction list or empty state ───────────────────────────────
          if (history.transactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyHistoryView(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TransactionTile(
                        transaction: history.transactions[index],
                      ),
                    );
                  },
                  childCount: history.transactions.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Balance card ─────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A35), Color(0xFF252545)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color.fromRGBO(255, 215, 0, 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(108, 99, 255, 0.18),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label ─────────────────────────────────────────────────────────
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: _kGold,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'AVAILABLE BALANCE',
                style: TextStyle(
                  color: _kGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Points (large) ────────────────────────────────────────────────
          Text(
            _formatPoints(wallet.points),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'points',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 24),

          // ── Divider ───────────────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFF2D2D4E)),
          const SizedBox(height: 20),

          // ── Summary stats ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'TOTAL DEPOSITED',
                  value: _formatPoints(wallet.totalDeposit),
                  valueColor: _kGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatColumn(
                  label: 'TOTAL WITHDRAWN',
                  value: _formatPoints(wallet.totalWithdraw),
                  valueColor: _kRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPoints(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kTextSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Transaction tile ─────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == 'deposit' ||
        transaction.type == 'reward' ||
        transaction.type == 'refund';
    final amountColor = isCredit ? _kGreen : _kRed;
    final amountPrefix = isCredit ? '+' : '-';
    final statusColor = _statusColor(transaction.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          // ── Type icon ──────────────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: amountColor.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _typeIcon(transaction.type),
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // ── Type label + date ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(transaction.type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(transaction.createdAt),
                  style: const TextStyle(color: _kTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          // ── Amount + status ────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${_formatAmount(transaction.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              _StatusPill(status: transaction.status, color: statusColor),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'deposit':
        return 'Deposit';
      case 'withdraw':
        return 'Withdrawal';
      case 'reward':
        return 'Reward';
      case 'entry_fee':
        return 'Entry Fee';
      case 'refund':
        return 'Refund';
      default:
        return type.isEmpty ? type : type[0].toUpperCase() + type.substring(1);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'deposit':
        return Icons.arrow_downward_rounded;
      case 'withdraw':
        return Icons.arrow_upward_rounded;
      case 'reward':
        return Icons.emoji_events_rounded;
      case 'entry_fee':
        return Icons.sports_esports_rounded;
      case 'refund':
        return Icons.undo_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return _kGreen;
      case 'pending':
        return _kAmber;
      case 'failed':
        return _kRed;
      case 'reversed':
        return _kTextSecondary;
      default:
        return _kTextSecondary;
    }
  }

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final month = months[dt.month - 1];
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $month ${dt.year}  $h:$mi';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Status pill ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final String status;
  final Color color;

  String get _label {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'reversed':
        return 'Reversed';
      default:
        return status.isEmpty
            ? status
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Empty history view ───────────────────────────────────────────────────────

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: _kTextSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your transaction history will appear here.',
            style: TextStyle(color: _kTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
