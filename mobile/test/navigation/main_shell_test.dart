import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/models/user_profile.dart';
import 'package:one_minute_ludo/features/home/screens/home_screen.dart';
import 'package:one_minute_ludo/features/profile/screens/profile_screen.dart';
import 'package:one_minute_ludo/features/profile/services/change_password_service.dart';
import 'package:one_minute_ludo/features/profile/services/profile_service.dart';
import 'package:one_minute_ludo/features/wallet/models/payment_result.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet_transaction.dart';
import 'package:one_minute_ludo/features/wallet/screens/wallet_screen.dart';
import 'package:one_minute_ludo/features/wallet/services/payment_service.dart';
import 'package:one_minute_ludo/features/wallet/services/wallet_service.dart';
import 'package:one_minute_ludo/navigation/main_shell.dart';

// ─── Test fixtures ────────────────────────────────────────────────────────────

const _kWallet = Wallet(
  id: 'wallet-uuid-1',
  points: 100.0,
  totalDeposit: 200.0,
  totalWithdraw: 50.0,
  updatedAt: '2026-07-18T10:00:00.000Z',
);

const _kTx = WalletTransaction(
  id: 'tx-uuid-1',
  type: 'deposit',
  amount: 200.0,
  status: 'completed',
  createdAt: '2026-07-18T10:00:00.000Z',
);

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake ProfileService — never resolves (loading state) ─────────────────────

class _FakeProfileService extends ProfileService {
  _FakeProfileService() : super(apiClient: _FakeApiClient());

  @override
  Future<UserProfile> getProfile() => Completer<UserProfile>().future;

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    Object? country = const Object(),
    Object? avatar = const Object(),
  }) =>
      Completer<UserProfile>().future;
}

// ─── Fake ChangePasswordService — no-op ───────────────────────────────────────

class _FakeChangePasswordService extends ChangePasswordService {
  _FakeChangePasswordService() : super(apiClient: _FakeApiClient());

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
}

// ─── Fake WalletService — never resolves (loading state) ─────────────────────

class _FakeWalletService extends WalletService {
  _FakeWalletService() : super(apiClient: _FakeApiClient());

  @override
  Future<Wallet> getWallet() => Completer<Wallet>().future;

  @override
  Future<WalletHistory> getHistory({int limit = 20, int offset = 0}) =>
      Completer<WalletHistory>().future;
}

// ─── Fake PaymentService — no-op ─────────────────────────────────────────────

class _FakePaymentService extends PaymentService {
  _FakePaymentService() : super(apiClient: _FakeApiClient());

  @override
  Future<PaymentResult> deposit({required double amount, String? reference}) async =>
      const PaymentResult(wallet: _kWallet, transaction: _kTx);

  @override
  Future<PaymentResult> withdraw({required double amount, String? reference}) async =>
      const PaymentResult(wallet: _kWallet, transaction: _kTx);
}

// ─── Widget pump helper ───────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onLogout,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
        walletService: _FakeWalletService(),
        paymentService: _FakePaymentService(),
        onLogout: onLogout ?? () {},
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  testWidgets('smoke — renders without crashing', (tester) async {
    await _pump(tester);
    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('BottomNavigationBar renders with three items', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('bottom_nav_bar')), findsOneWidget);
    // Each item has a text label
    expect(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Profile'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Wallet'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home tab is selected and HomeScreen is shown by default',
      (tester) async {
    await _pump(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    // AppBar title shows "Home"
    expect(
      find.descendant(
        of: find.byKey(const Key('main_shell_app_bar')),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('AppBar title updates to "Profile" when Profile tab is tapped',
      (tester) async {
    await _pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Profile'),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('main_shell_app_bar')),
        matching: find.text('Profile'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ProfileScreen is in the stack after tapping Profile tab',
      (tester) async {
    await _pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Profile'),
      ),
    );
    await tester.pump();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('AppBar title updates to "Wallet" when Wallet tab is tapped',
      (tester) async {
    await _pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Wallet'),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('main_shell_app_bar')),
        matching: find.text('Wallet'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('WalletScreen is in the stack after tapping Wallet tab',
      (tester) async {
    await _pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Wallet'),
      ),
    );
    await tester.pump();
    expect(find.byType(WalletScreen), findsOneWidget);
  });

  testWidgets('can switch between tabs and back to Home', (tester) async {
    await _pump(tester);

    // Navigate to Profile
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Profile'),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('main_shell_app_bar')),
        matching: find.text('Profile'),
      ),
      findsOneWidget,
    );

    // Navigate back to Home
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('bottom_nav_bar')),
        matching: find.text('Home'),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('main_shell_app_bar')),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('logout button fires onLogout callback', (tester) async {
    var logoutCalled = false;
    await _pump(tester, onLogout: () => logoutCalled = true);
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pump();
    expect(logoutCalled, isTrue);
  });

  testWidgets('logout button has the correct tooltip', (tester) async {
    await _pump(tester);
    final btn = tester.widget<IconButton>(
      find.byKey(const Key('logout_button')),
    );
    expect(btn.tooltip, 'Log out');
  });
}
