import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/errors/api_exception.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet_transaction.dart';
import 'package:one_minute_ludo/features/wallet/screens/wallet_screen.dart';
import 'package:one_minute_ludo/features/wallet/services/wallet_service.dart';

// ─── Test fixtures ────────────────────────────────────────────────────────────

const _kWallet = Wallet(
  id: 'wallet-uuid-1',
  points: 250.0,
  totalDeposit: 500.0,
  totalWithdraw: 150.0,
  updatedAt: '2026-07-18T10:00:00.000Z',
);

const _kZeroWallet = Wallet(
  id: 'wallet-uuid-2',
  points: 0.0,
  totalDeposit: 0.0,
  totalWithdraw: 0.0,
  updatedAt: '2026-07-18T00:00:00.000Z',
);

const _kTx1 = WalletTransaction(
  id: 'tx-uuid-1',
  type: 'reward',
  amount: 50.0,
  status: 'completed',
  createdAt: '2026-07-18T12:00:00.000Z',
);

const _kTx2 = WalletTransaction(
  id: 'tx-uuid-2',
  type: 'entry_fee',
  amount: 10.0,
  status: 'completed',
  createdAt: '2026-07-17T09:30:00.000Z',
);

const _kTxDeposit = WalletTransaction(
  id: 'tx-uuid-3',
  type: 'deposit',
  amount: 200.0,
  status: 'pending',
  createdAt: '2026-07-16T08:00:00.000Z',
);

WalletHistory _emptyHistory() => const WalletHistory(
      transactions: [],
      total: 0,
      limit: 20,
      offset: 0,
    );

WalletHistory _historyWith(List<WalletTransaction> txs) => WalletHistory(
      transactions: txs,
      total: txs.length,
      limit: 20,
      offset: 0,
    );

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

/// Minimal stub that satisfies the WalletService constructor without opening
/// any platform channels.  The service methods are overridden in the fake
/// subclass below, so the ApiClient is never actually called.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake WalletService ───────────────────────────────────────────────────────

class _FakeWalletService extends WalletService {
  _FakeWalletService({
    Wallet walletResponse = _kWallet,
    WalletHistory? historyResponse,
    Exception? getWalletError,
    Exception? getHistoryError,
  })  : _walletResponse = walletResponse,
        _historyResponse = historyResponse ?? _emptyHistory(),
        _getWalletError = getWalletError,
        _getHistoryError = getHistoryError,
        super(apiClient: _FakeApiClient());

  final Wallet _walletResponse;
  final WalletHistory _historyResponse;
  final Exception? _getWalletError;
  final Exception? _getHistoryError;

  @override
  Future<Wallet> getWallet() async {
    if (_getWalletError != null) throw _getWalletError;
    return _walletResponse;
  }

  @override
  Future<WalletHistory> getHistory({int limit = 20, int offset = 0}) async {
    if (_getHistoryError != null) throw _getHistoryError;
    return _historyResponse;
  }
}

// ─── Widget pump helpers ──────────────────────────────────────────────────────

/// Wraps [WalletScreen] in a [MaterialApp] and pumps it.
Future<void> _pump(WidgetTester tester, WalletService walletService) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WalletScreen(walletService: walletService),
    ),
  );
}

/// Flushes the async chain from initState (one microtask hop per await in the
/// fake service, then one frame rebuild).  Three pump() calls are sufficient
/// for the fake implementations.  We avoid pumpAndSettle() here because the
/// AnimatedSwitcher's outgoing child may briefly show a CircularProgressIndicator
/// whose continuous animation never settles.
Future<void> _pumpLoaded(WidgetTester tester) async {
  await tester.pump(); // schedules microtask
  await tester.pump(); // fake futures resolve → setState
  await tester.pump(const Duration(milliseconds: 300)); // AnimatedSwitcher
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── 1: Smoke — renders without crashing ──────────────────────────────────
  testWidgets(
    'WalletScreen 1 — renders without crashing (initial loading state)',
    (tester) async {
      await _pump(tester, _FakeWalletService());
      expect(find.byType(WalletScreen), findsOneWidget);
    },
  );

  // ── 2: Loading indicator shown initially ──────────────────────────────────
  testWidgets(
    'WalletScreen 2 — shows CircularProgressIndicator before data arrives',
    (tester) async {
      await _pump(tester, _FakeWalletService());
      // On the very first frame the initState futures have not yet resolved.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('250'), findsNothing);
    },
  );

  // ── 3: Balance card displayed after load ─────────────────────────────────
  testWidgets(
    'WalletScreen 3 — displays wallet balance after successful load',
    (tester) async {
      await _pump(tester, _FakeWalletService());
      await _pumpLoaded(tester);

      // Points balance shown prominently
      expect(find.text('250'), findsOneWidget);
      // 'points' label beneath the large number
      expect(find.text('points'), findsOneWidget);
      // App bar title
      expect(find.text('My Wallet'), findsOneWidget);
    },
  );

  // ── 4: Zero balance shown correctly ──────────────────────────────────────
  testWidgets(
    'WalletScreen 4 — displays zero balance without crashing',
    (tester) async {
      await _pump(
        tester,
        _FakeWalletService(walletResponse: _kZeroWallet),
      );
      await _pumpLoaded(tester);

      // '0' appears at least once for the points display
      expect(find.text('0'), findsWidgets);
      expect(find.text('points'), findsOneWidget);
    },
  );

  // ── 5: Empty history shows empty-state view ───────────────────────────────
  testWidgets(
    'WalletScreen 5 — shows empty history view when there are no transactions',
    (tester) async {
      await _pump(
        tester,
        _FakeWalletService(historyResponse: _emptyHistory()),
      );
      await _pumpLoaded(tester);

      expect(find.text('No transactions yet'), findsOneWidget);
      expect(
        find.text('Your transaction history will appear here.'),
        findsOneWidget,
      );
    },
  );

  // ── 6: Transaction list displayed when history is non-empty ───────────────
  testWidgets(
    'WalletScreen 6 — displays transaction tiles when history is non-empty',
    (tester) async {
      await _pump(
        tester,
        _FakeWalletService(
          historyResponse: _historyWith([_kTx1, _kTx2]),
        ),
      );
      await _pumpLoaded(tester);

      // Type labels from the two transactions
      expect(find.text('Reward'), findsOneWidget);
      expect(find.text('Entry Fee'), findsOneWidget);
      // No empty-state copy
      expect(find.text('No transactions yet'), findsNothing);
    },
  );

  // ── 7: Deposit transaction shown as credit (prefix +) ────────────────────
  testWidgets(
    'WalletScreen 7 — deposit transaction shows + prefix and Deposit label',
    (tester) async {
      await _pump(
        tester,
        _FakeWalletService(
          historyResponse: _historyWith([_kTxDeposit]),
        ),
      );
      await _pumpLoaded(tester);

      expect(find.text('Deposit'), findsOneWidget);
      expect(find.text('+200'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    },
  );

  // ── 8: Error state shown when wallet load fails ───────────────────────────
  testWidgets(
    'WalletScreen 8 — shows error state when wallet load fails',
    (tester) async {
      await _pump(
        tester,
        _FakeWalletService(
          getWalletError: const ApiException(
            statusCode: 500,
            message: 'Internal server error.',
          ),
        ),
      );
      await _pumpLoaded(tester);

      expect(find.text('Could not load wallet'), findsOneWidget);
      expect(find.text('Internal server error.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('250'), findsNothing);
    },
  );

  // ── 9: Retry button reloads and shows wallet on success ──────────────────
  testWidgets(
    'WalletScreen 9 — Retry button reloads and shows wallet on success',
    (tester) async {
      final service = _CountingWalletService(failFirst: true);
      await _pump(tester, service);
      await _pumpLoaded(tester);

      expect(find.text('Retry'), findsOneWidget);
      final countBefore = service.callCount;

      await tester.tap(find.text('Retry'));
      await _pumpLoaded(tester);

      expect(service.callCount, greaterThan(countBefore));
      expect(find.text('250'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  // ── 10: Pull-to-refresh triggers a reload ────────────────────────────────
  testWidgets(
    'WalletScreen 10 — pull-to-refresh triggers a second load',
    (tester) async {
      final service = _CountingWalletService(failFirst: false);
      await _pump(tester, service);
      await _pumpLoaded(tester);

      expect(find.text('250'), findsOneWidget);
      final countBefore = service.callCount;

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, 300),
      );
      await tester.pump();
      await _pumpLoaded(tester);

      expect(service.callCount, greaterThan(countBefore));
    },
  );
}

// ─── Helper: counting wallet service ─────────────────────────────────────────

/// A [WalletService] fake that counts [getWallet] calls and optionally fails
/// the first call to exercise the retry logic (test 9).
class _CountingWalletService extends WalletService {
  _CountingWalletService({required this.failFirst})
      : super(apiClient: _FakeApiClient());

  final bool failFirst;
  int callCount = 0;

  @override
  Future<Wallet> getWallet() async {
    callCount += 1;
    if (failFirst && callCount == 1) {
      throw const ApiException(
        statusCode: 500,
        message: 'Temporary failure.',
      );
    }
    return _kWallet;
  }

  @override
  Future<WalletHistory> getHistory({int limit = 20, int offset = 0}) async {
    return _emptyHistory();
  }
}
