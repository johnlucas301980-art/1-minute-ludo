import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/payment_result.dart';

/// Provides payment operations (deposit and withdraw) for the 1 Minute Ludo app.
///
/// Wraps POST /api/wallet/deposit and POST /api/wallet/withdraw.
///
/// All dependencies are injected through the constructor — no singletons.
///
/// Usage:
/// ```dart
/// final storage  = TokenStorage();
/// final client   = ApiClient(tokenStorage: storage);
/// final payments = PaymentService(apiClient: client);
///
/// // Deposit
/// try {
///   final result = await payments.deposit(amount: 500);
///   // result.wallet  — updated wallet snapshot
///   // result.transaction — the completed deposit record
/// } on SessionExpiredException {
///   // navigate to login
/// } on ApiException catch (e) {
///   // surface e.message
/// }
///
/// // Withdraw
/// try {
///   final result = await payments.withdraw(amount: 200);
/// } on InsufficientBalanceException {
///   // show balance error
/// } on SessionExpiredException {
///   // navigate to login
/// } on ApiException catch (e) {
///   // surface e.message
/// }
/// ```
class PaymentService {
  PaymentService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Deposit ─────────────────────────────────────────────────────────────────

  /// Credits [amount] points to the authenticated player's wallet.
  ///
  /// This is a provider-agnostic ledger operation: the caller is responsible
  /// for verifying that the real-world payment succeeded before calling this
  /// method.
  ///
  /// [amount] must be a positive number (validated server-side).
  /// [reference] is an optional external reference string (e.g. a gateway
  /// transaction ID) stored alongside the transaction record for audit purposes.
  ///
  /// Returns a [PaymentResult] containing the updated wallet snapshot and the
  /// completed deposit transaction record.
  ///
  /// Throws [ApiException] on validation failures (400) or server errors (5xx).
  /// Throws [SessionExpiredException] when the access token is absent or the
  /// refresh token is expired.
  Future<PaymentResult> deposit({
    required double amount,
    String? reference,
  }) async {
    final body = <String, dynamic>{'amount': amount};
    if (reference != null) body['reference'] = reference;

    final json = await _api.authenticatedRequest(
      'POST',
      '/wallet/deposit',
      body: body,
    );
    final data = json['data'] as Map<String, dynamic>;
    return PaymentResult.fromJson(data);
  }

  // ─── Withdraw ────────────────────────────────────────────────────────────────

  /// Debits [amount] points from the authenticated player's wallet.
  ///
  /// [amount] must be a positive number that does not exceed the current
  /// wallet balance (both validated server-side).
  /// [reference] is an optional external reference string.
  ///
  /// Returns a [PaymentResult] containing the updated wallet snapshot and the
  /// completed withdrawal transaction record.
  ///
  /// Throws [InsufficientBalanceException] when the player's balance is too low
  /// (HTTP 422) — the session remains active; tokens are NOT cleared.
  /// Throws [ApiException] on validation failures (400) or server errors (5xx).
  /// Throws [SessionExpiredException] when the access token is absent or the
  /// refresh token is expired.
  Future<PaymentResult> withdraw({
    required double amount,
    String? reference,
  }) async {
    final body = <String, dynamic>{'amount': amount};
    if (reference != null) body['reference'] = reference;

    try {
      final json = await _api.authenticatedRequest(
        'POST',
        '/wallet/withdraw',
        body: body,
      );
      final data = json['data'] as Map<String, dynamic>;
      return PaymentResult.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 422) {
        throw InsufficientBalanceException(message: e.message);
      }
      rethrow;
    }
  }
}
