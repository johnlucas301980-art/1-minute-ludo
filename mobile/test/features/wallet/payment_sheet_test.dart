import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/wallet/models/payment_result.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet_transaction.dart';
import 'package:one_minute_ludo/features/wallet/services/payment_service.dart';
import 'package:one_minute_ludo/features/wallet/widgets/deposit_sheet.dart';
import 'package:one_minute_ludo/features/wallet/widgets/withdraw_sheet.dart';

// ─── Test fixtures ────────────────────────────────────────────────────────────

const _kWallet = Wallet(
  id: 'wallet-uuid-1',
  points: 800.0,
  totalDeposit: 1000.0,
  totalWithdraw: 200.0,
  updatedAt: '2026-07-18T12:00:00.000Z',
);

const _kDepositTx = WalletTransaction(
  id: 'tx-deposit-1',
  type: 'deposit',
  amount: 500.0,
  status: 'completed',
  createdAt: '2026-07-18T12:00:00.000Z',
);

const _kWithdrawTx = WalletTransaction(
  id: 'tx-withdraw-1',
  type: 'withdraw',
  amount: 200.0,
  status: 'completed',
  createdAt: '2026-07-18T12:05:00.000Z',
);

const _kDepositResult = PaymentResult(wallet: _kWallet, transaction: _kDepositTx);
const _kWithdrawResult = PaymentResult(wallet: _kWallet, transaction: _kWithdrawTx);

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

/// Minimal stub satisfying the PaymentService constructor without opening
/// platform channels.  The fake service overrides all methods so this is
/// never actually invoked.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake PaymentService ──────────────────────────────────────────────────────

class _FakePaymentService extends PaymentService {
  _FakePaymentService({
    PaymentResult depositResponse = _kDepositResult,
    PaymentResult withdrawResponse = _kWithdrawResult,
    Exception? depositError,
    Exception? withdrawError,
  })  : _depositResponse = depositResponse,
        _depositError = depositError,
        _withdrawResponse = withdrawResponse,
        _withdrawError = withdrawError,
        super(apiClient: _FakeApiClient());

  final PaymentResult _depositResponse;
  final Exception? _depositError;
  final PaymentResult _withdrawResponse;
  final Exception? _withdrawError;

  @override
  Future<PaymentResult> deposit({
    required double amount,
    String? reference,
  }) async {
    if (_depositError != null) throw _depositError;
    return _depositResponse;
  }

  @override
  Future<PaymentResult> withdraw({
    required double amount,
    String? reference,
  }) async {
    if (_withdrawError != null) throw _withdrawError;
    return _withdrawResponse;
  }
}

// ─── Capturing PaymentService ─────────────────────────────────────────────────

/// Records the most recent call arguments so tests can assert on them.
class _CapturingPaymentService extends PaymentService {
  _CapturingPaymentService() : super(apiClient: _FakeApiClient());

  double? capturedDepositAmount;
  String? capturedDepositReference;
  double? capturedWithdrawAmount;
  String? capturedWithdrawReference;

  @override
  Future<PaymentResult> deposit({
    required double amount,
    String? reference,
  }) async {
    capturedDepositAmount = amount;
    capturedDepositReference = reference;
    return _kDepositResult;
  }

  @override
  Future<PaymentResult> withdraw({
    required double amount,
    String? reference,
  }) async {
    capturedWithdrawAmount = amount;
    capturedWithdrawReference = reference;
    return _kWithdrawResult;
  }
}

// ─── Widget pump helpers ──────────────────────────────────────────────────────

Future<void> _pumpDeposit(
  WidgetTester tester,
  PaymentService service, {
  ValueChanged<PaymentResult>? onSuccess,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DepositSheet(
          paymentService: service,
          onSuccess: onSuccess ?? (_) {},
        ),
      ),
    ),
  );
}

Future<void> _pumpWithdraw(
  WidgetTester tester,
  PaymentService service, {
  double currentBalance = 1000.0,
  ValueChanged<PaymentResult>? onSuccess,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WithdrawSheet(
          paymentService: service,
          currentBalance: currentBalance,
          onSuccess: onSuccess ?? (_) {},
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ════════════════════════════════════════════════════════════════════════════
  // DepositSheet
  // ════════════════════════════════════════════════════════════════════════════

  group('DepositSheet', () {
    // ── 1: Smoke ────────────────────────────────────────────────────────────
    testWidgets(
      'DepositSheet 1 — renders without crashing and shows title',
      (tester) async {
        await _pumpDeposit(tester, _FakePaymentService());
        expect(find.byType(DepositSheet), findsOneWidget);
        expect(find.text('Deposit Points'), findsOneWidget);
      },
    );

    // ── 2: Fields present ───────────────────────────────────────────────────
    testWidgets(
      'DepositSheet 2 — shows amount field, reference field, and Deposit button',
      (tester) async {
        await _pumpDeposit(tester, _FakePaymentService());
        // Two TextFormFields: amount + reference
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(
          find.widgetWithText(ElevatedButton, 'Deposit'),
          findsOneWidget,
        );
      },
    );

    // ── 3: Empty amount validation ──────────────────────────────────────────
    testWidgets(
      'DepositSheet 3 — empty amount shows "Amount is required." validation error',
      (tester) async {
        await _pumpDeposit(tester, _FakePaymentService());

        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump();

        expect(find.text('Amount is required.'), findsOneWidget);
      },
    );

    // ── 4: Invalid (non-numeric) amount ─────────────────────────────────────
    testWidgets(
      'DepositSheet 4 — non-parseable amount shows "Enter a valid number."',
      (tester) async {
        await _pumpDeposit(tester, _FakePaymentService());

        // Enter only dots — passes the field but fails double.tryParse
        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '...');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump();

        expect(find.text('Enter a valid number.'), findsOneWidget);
      },
    );

    // ── 5: Zero amount validation ───────────────────────────────────────────
    testWidgets(
      'DepositSheet 5 — zero amount shows "Amount must be greater than zero."',
      (tester) async {
        await _pumpDeposit(tester, _FakePaymentService());

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '0');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump();

        expect(find.text('Amount must be greater than zero.'), findsOneWidget);
      },
    );

    // ── 6: Successful deposit — onSuccess called ────────────────────────────
    testWidgets(
      'DepositSheet 6 — successful deposit calls onSuccess with PaymentResult',
      (tester) async {
        PaymentResult? received;

        await _pumpDeposit(
          tester,
          _FakePaymentService(),
          onSuccess: (r) => received = r,
        );

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '500');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump(); // future resolves
        await tester.pump(); // setState

        expect(received, isNotNull);
        expect(received!.transaction.type, 'deposit');
        expect(received!.wallet.points, 800.0);
      },
    );

    // ── 7: Amount and reference forwarded to service ────────────────────────
    testWidgets(
      'DepositSheet 7 — amount and reference are forwarded to PaymentService',
      (tester) async {
        final capturing = _CapturingPaymentService();
        await _pumpDeposit(tester, capturing);

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), '250.50');
        await tester.enterText(fields.at(1), 'GW-TX-001');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump();
        await tester.pump();

        expect(capturing.capturedDepositAmount, 250.50);
        expect(capturing.capturedDepositReference, 'GW-TX-001');
      },
    );

    // ── 8: Blank reference is NOT forwarded (null, not empty string) ────────
    testWidgets(
      'DepositSheet 8 — blank reference field sends null reference to service',
      (tester) async {
        final capturing = _CapturingPaymentService();
        await _pumpDeposit(tester, capturing);

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '100');
        // leave reference blank
        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump();
        await tester.pump();

        expect(capturing.capturedDepositAmount, 100.0);
        expect(capturing.capturedDepositReference, isNull);
      },
    );

    // ── 9: ApiException — error banner shown, sheet stays open ─────────────
    testWidgets(
      'DepositSheet 9 — ApiException shows error banner, form stays visible',
      (tester) async {
        await _pumpDeposit(
          tester,
          _FakePaymentService(
            depositError: const ApiException(
              statusCode: 500,
              message: 'Internal server error.',
            ),
          ),
        );

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '100');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump(); // exception caught
        await tester.pump(); // setState rebuild

        expect(find.text('Internal server error.'), findsOneWidget);
        // Sheet stays open: both fields still present
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );

    // ── 10: SessionExpiredException — session-expired banner ────────────────
    testWidgets(
      'DepositSheet 10 — SessionExpiredException shows session-expired banner',
      (tester) async {
        await _pumpDeposit(
          tester,
          _FakePaymentService(depositError: SessionExpiredException()),
        );

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '100');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Session expired. Please log in again.'),
          findsOneWidget,
        );
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // WithdrawSheet
  // ════════════════════════════════════════════════════════════════════════════

  group('WithdrawSheet', () {
    // ── 11: Smoke ───────────────────────────────────────────────────────────
    testWidgets(
      'WithdrawSheet 11 — renders without crashing and shows title',
      (tester) async {
        await _pumpWithdraw(tester, _FakePaymentService());
        expect(find.byType(WithdrawSheet), findsOneWidget);
        expect(find.text('Withdraw Points'), findsOneWidget);
      },
    );

    // ── 12: Balance and fields ─────────────────────────────────────────────
    testWidgets(
      'WithdrawSheet 12 — shows current balance, amount field, reference field',
      (tester) async {
        await _pumpWithdraw(
          tester,
          _FakePaymentService(),
          currentBalance: 750.0,
        );

        // Balance chip
        expect(find.text('750 pts'), findsOneWidget);
        // Two TextFormFields: amount + reference
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(
          find.widgetWithText(ElevatedButton, 'Withdraw'),
          findsOneWidget,
        );
      },
    );

    // ── 13: Current balance displayed with decimal formatting ───────────────
    testWidgets(
      'WithdrawSheet 13 — fractional balance shown with two decimal places',
      (tester) async {
        await _pumpWithdraw(
          tester,
          _FakePaymentService(),
          currentBalance: 123.45,
        );

        expect(find.text('123.45 pts'), findsOneWidget);
      },
    );

    // ── 14: Empty amount validation ─────────────────────────────────────────
    testWidgets(
      'WithdrawSheet 14 — empty amount shows "Amount is required."',
      (tester) async {
        await _pumpWithdraw(tester, _FakePaymentService());

        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();

        expect(find.text('Amount is required.'), findsOneWidget);
      },
    );

    // ── 15: Zero amount validation ──────────────────────────────────────────
    testWidgets(
      'WithdrawSheet 15 — zero amount shows "Amount must be greater than zero."',
      (tester) async {
        await _pumpWithdraw(tester, _FakePaymentService());

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '0');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();

        expect(find.text('Amount must be greater than zero.'), findsOneWidget);
      },
    );

    // ── 16: Successful withdraw — onSuccess called ──────────────────────────
    testWidgets(
      'WithdrawSheet 16 — successful withdraw calls onSuccess with PaymentResult',
      (tester) async {
        PaymentResult? received;

        await _pumpWithdraw(
          tester,
          _FakePaymentService(),
          onSuccess: (r) => received = r,
        );

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '200');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();
        await tester.pump();

        expect(received, isNotNull);
        expect(received!.transaction.type, 'withdraw');
        expect(received!.transaction.amount, 200.0);
      },
    );

    // ── 17: InsufficientBalanceException — inline error, session intact ─────
    testWidgets(
      'WithdrawSheet 17 — InsufficientBalanceException shows inline balance '
      'error; sheet stays open (session is not cleared)',
      (tester) async {
        await _pumpWithdraw(
          tester,
          _FakePaymentService(withdrawError: InsufficientBalanceException()),
        );

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '9999');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
              'Insufficient balance. Please enter a lower amount.'),
          findsOneWidget,
        );
        // Form stays open
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );

    // ── 18: ApiException (500) — error banner shown ─────────────────────────
    testWidgets(
      'WithdrawSheet 18 — ApiException shows error banner, sheet stays open',
      (tester) async {
        await _pumpWithdraw(
          tester,
          _FakePaymentService(
            withdrawError: const ApiException(
              statusCode: 500,
              message: 'Payment service unavailable.',
            ),
          ),
        );

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '100');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Payment service unavailable.'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );

    // ── 19: SessionExpiredException — session-expired banner ────────────────
    testWidgets(
      'WithdrawSheet 19 — SessionExpiredException shows session-expired banner',
      (tester) async {
        await _pumpWithdraw(
          tester,
          _FakePaymentService(withdrawError: SessionExpiredException()),
        );

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '100');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Session expired. Please log in again.'),
          findsOneWidget,
        );
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );

    // ── 20: Amount and reference forwarded; blank reference → null ──────────
    testWidgets(
      'WithdrawSheet 20 — amount and reference forwarded to service; '
      'blank reference field sends null',
      (tester) async {
        final capturing = _CapturingPaymentService();
        await _pumpWithdraw(tester, capturing);

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), '150');
        await tester.enterText(fields.at(1), 'PAYOUT-001');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();
        await tester.pump();

        expect(capturing.capturedWithdrawAmount, 150.0);
        expect(capturing.capturedWithdrawReference, 'PAYOUT-001');
      },
    );

    // ── 21: Blank reference sends null (separate pump to avoid nav state) ───
    testWidgets(
      'WithdrawSheet 21 — blank reference field sends null to service',
      (tester) async {
        final capturing = _CapturingPaymentService();
        await _pumpWithdraw(tester, capturing);

        final amountField = find.byType(TextFormField).first;
        await tester.enterText(amountField, '75');
        // leave reference blank
        await tester.tap(find.widgetWithText(ElevatedButton, 'Withdraw'));
        await tester.pump();
        await tester.pump();

        expect(capturing.capturedWithdrawAmount, 75.0);
        expect(capturing.capturedWithdrawReference, isNull);
      },
    );
  });
}
