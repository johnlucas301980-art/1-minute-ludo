import 'wallet_transaction.dart';

/// Represents the authenticated player's wallet balance as returned by
/// GET /api/wallet.
///
/// [points], [totalDeposit], and [totalWithdraw] are returned as numbers by
/// the backend; [updatedAt] is an ISO-8601 timestamp string.
class Wallet {
  const Wallet({
    required this.id,
    required this.points,
    required this.totalDeposit,
    required this.totalWithdraw,
    required this.updatedAt,
  });

  final String id;
  final double points;
  final double totalDeposit;
  final double totalWithdraw;
  final String updatedAt;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      points: (json['points'] as num).toDouble(),
      totalDeposit: (json['total_deposit'] as num).toDouble(),
      totalWithdraw: (json['total_withdraw'] as num).toDouble(),
      updatedAt: json['updated_at'] as String,
    );
  }

  @override
  String toString() =>
      'Wallet(points: $points, totalDeposit: $totalDeposit, totalWithdraw: $totalWithdraw)';
}

/// Represents a paginated page of transaction history as returned by
/// GET /api/wallet/history.
///
/// [total] is the count of transactions included in this response page
/// (equivalent to `transactions.length`; provided by `pagination.count`
/// in the backend envelope).
class WalletHistory {
  const WalletHistory({
    required this.transactions,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<WalletTransaction> transactions;

  /// Number of transactions returned in this page (`pagination.count`).
  final int total;
  final int limit;
  final int offset;

  factory WalletHistory.fromJson(Map<String, dynamic> data) {
    final rawList = data['transactions'] as List<dynamic>;
    final pagination = data['pagination'] as Map<String, dynamic>;

    return WalletHistory(
      transactions: rawList
          .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination['count'] as int,
      limit: pagination['limit'] as int,
      offset: pagination['offset'] as int,
    );
  }

  @override
  String toString() =>
      'WalletHistory(total: $total, limit: $limit, offset: $offset, '
      'transactions: ${transactions.length})';
}
