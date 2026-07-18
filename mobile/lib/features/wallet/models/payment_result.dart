import 'wallet.dart';
import 'wallet_transaction.dart';

/// Returned by [PaymentService.deposit] and [PaymentService.withdraw].
///
/// Carries the updated wallet snapshot and the completed transaction record
/// as returned by POST /api/wallet/deposit and POST /api/wallet/withdraw.
class PaymentResult {
  const PaymentResult({
    required this.wallet,
    required this.transaction,
  });

  final Wallet wallet;
  final WalletTransaction transaction;

  factory PaymentResult.fromJson(Map<String, dynamic> data) {
    return PaymentResult(
      wallet: Wallet.fromJson(data['wallet'] as Map<String, dynamic>),
      transaction: WalletTransaction.fromJson(
        data['transaction'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  String toString() =>
      'PaymentResult(wallet: $wallet, transaction: $transaction)';
}
