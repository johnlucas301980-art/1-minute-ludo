/// A single ledger entry as returned within GET /api/wallet/history.
///
/// [type] is one of: deposit | withdraw | reward | entry_fee | refund.
/// [status] is one of: pending | completed | failed | reversed.
/// [amount] is returned as a number by the backend.
/// [reference] is an optional external reference string (may be null).
/// [createdAt] is an ISO-8601 timestamp string.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String type;
  final double amount;
  final String status;
  final String? reference;
  final String createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      reference: json['reference'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  @override
  String toString() =>
      'WalletTransaction(id: $id, type: $type, amount: $amount, status: $status)';
}
