/// Wallet records exposed to administrators — Phase 10.4.

class AdminWallet {
  const AdminWallet({
    required this.walletId,
    required this.userId,
    required this.playerId,
    required this.fullName,
    required this.userStatus,
    required this.points,
    required this.totalDeposit,
    required this.totalWithdraw,
    required this.transactionCount,
    this.lastTransactionAt,
    required this.updatedAt,
  });

  final String walletId;
  final String userId;
  final String playerId;
  final String fullName;
  final String userStatus;
  final double points;
  final double totalDeposit;
  final double totalWithdraw;
  final int transactionCount;
  final DateTime? lastTransactionAt;
  final DateTime updatedAt;

  factory AdminWallet.fromJson(Map<String, dynamic> json) {
    String stringValue(String key) {
      final value = json[key];
      if (value is! String) throw FormatException('Expected string for $key.');
      return value;
    }

    double numberValue(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.parse(value);
      throw FormatException('Expected number for $key.');
    }

    DateTime dateValue(String key) => DateTime.parse(stringValue(key)).toLocal();

    return AdminWallet(
      walletId: stringValue('wallet_id'),
      userId: stringValue('user_id'),
      playerId: stringValue('player_id'),
      fullName: stringValue('full_name'),
      userStatus: stringValue('user_status'),
      points: numberValue('points'),
      totalDeposit: numberValue('total_deposit'),
      totalWithdraw: numberValue('total_withdraw'),
      transactionCount: (json['transaction_count'] as num?)?.toInt() ??
          int.parse(json['transaction_count'].toString()),
      lastTransactionAt: json['last_transaction_at'] is String
          ? DateTime.parse(json['last_transaction_at'] as String).toLocal()
          : null,
      updatedAt: dateValue('updated_at'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminWallet && walletId == other.walletId;

  @override
  int get hashCode => walletId.hashCode;
}

class AdminWalletTransaction {
  const AdminWalletTransaction({
    required this.id,
    required this.userId,
    required this.playerId,
    required this.fullName,
    required this.type,
    required this.amount,
    required this.status,
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String playerId;
  final String fullName;
  final String type;
  final double amount;
  final String status;
  final String? reference;
  final DateTime createdAt;

  factory AdminWalletTransaction.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return AdminWalletTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      playerId: json['player_id'] as String,
      fullName: json['full_name'] as String,
      type: json['type'] as String,
      amount: amount is num ? amount.toDouble() : double.parse(amount.toString()),
      status: json['status'] as String,
      reference: json['reference'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminWalletTransaction && id == other.id;

  @override
  int get hashCode => id.hashCode;
}