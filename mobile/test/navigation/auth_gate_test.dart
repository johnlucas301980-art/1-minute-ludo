import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/models/user_profile.dart';
import 'package:one_minute_ludo/features/auth/screens/login_screen.dart';
import 'package:one_minute_ludo/features/auth/screens/register_screen.dart';
import 'package:one_minute_ludo/features/profile/services/change_password_service.dart';
import 'package:one_minute_ludo/features/profile/services/profile_service.dart';
import 'package:one_minute_ludo/features/wallet/models/payment_result.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet.dart';
import 'package:one_minute_ludo/features/wallet/models/wallet_transaction.dart';
import 'package:one_minute_ludo/features/wallet/services/payment_service.dart';
import 'package:one_minute_ludo/features/wallet/services/wallet_service.dart';
import 'package:one_minute_ludo/navigation/auth_gate.dart';
import 'package:one_minute_ludo/features/auth/services/auth_service.dart';
import 'package:one_minute_ludo/navigation/main_shell.dart';

// ─── Test fixtures ────────────────────────────────────────────────────────────

const _kProfile = UserProfile(
  id: 'user-uuid-1',
  playerId: 'LUD-ABC123',
  fullName: 'Test Player',
  email: 'test@example.com',
  status: 'active',
  createdAt: '2026-07-18T00:00:00.000Z',
);

const _kWallet = Wallet(
  id: 'wallet-uuid-1',
  points: 0.0,
  totalDeposit: 0.0,
  totalWithdraw: 0.0,
  updatedAt: '2026-07-18T00:00:00.000Z',
);

const _kTx = WalletTransaction(
  id: 'tx-uuid-1',
  type: 'deposit',
  amount: 0.0,
  status: 'completed',
  createdAt: '2026-07-18T00:00:00.000Z',
);

// ─── Fake ApiClient ───────────────────────────────────────────────────────────

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

// ─── Fake AuthService ────────────────────────────────────────────────────────

/// Configurable fake: [loggedIn] controls [isLoggedIn]; [loginError] /
/// [registerError] optionally throw on the respective auth calls.
class _FakeAuthService extends AuthService {
  _FakeAuthService({
    bool loggedIn = false,
    Future<bool>? isLoggedInFuture,
    UserProfile loginResponse = _kProfile,
    UserProfile registerResponse = _kProfile,
    Exception? loginError,
    Exception? registerError,
  })  : _loggedIn = loggedIn,
        _isLoggedInFuture = isLoggedInFuture,
        _loginResponse = loginResponse,
        _registerResponse = registerResponse,
        _loginError = loginError,
        _registerError = registerError,
        super(
          apiClient: _FakeApiClient(),
          tokenStorage: const TokenStorage(),
        );

  final bool _loggedIn;
  final Future<bool>? _isLoggedInFuture;
  final UserProfile _loginResponse;
  final UserProfile _registerResponse;
  final Exception? _loginError;
  final Exception? _registerError;

  @override
  Future<bool> isLoggedIn() =>
      _isLoggedInFuture ?? Future.value(_loggedIn);

  @override
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    if (_loginError != null) throw _loginError;
    return _loginResponse;
  }

  @override
  Future<UserProfile> register({
    required String fullName,
    required String password,
    String? email,
    String? mobile,
    String? country,
  }) async {
    if (_registerError != null) throw _registerError;
    return _registerResponse;
  }

  @override
  Future<void> logout({bool allDevices = false}) async {}
}

// ─── Fake ProfileService — never resolves ─────────────────────────────────────

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

// ─── Fake WalletService — never resolves ─────────────────────────────────────

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
  required _FakeAuthService authService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuthGate(
        authService: authService,
        profileService: _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
        walletService: _FakeWalletService(),
        paymentService: _FakePaymentService(),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── Initial loading state ──────────────────────────────────────────────────

  testWidgets('smoke — renders without crashing', (tester) async {
    await _pump(tester, authService: _FakeAuthService());
    expect(find.byType(AuthGate), findsOneWidget);
  });

  testWidgets(
      'shows loading indicator while session check is pending',
      (tester) async {
    // Never-resolving isLoggedIn — gate stays in checking state.
    final authService = _FakeAuthService(
      isLoggedInFuture: Completer<bool>().future,
    );
    await _pump(tester, authService: authService);
    // pumpWidget triggers initState; the async hasn't completed yet.
    expect(find.byKey(const Key('auth_gate_loading')), findsOneWidget);
  });

  // ── Unauthenticated routing ────────────────────────────────────────────────

  testWidgets('shows LoginScreen when not logged in', (tester) async {
    await _pump(tester, authService: _FakeAuthService(loggedIn: false));
    await tester.pump(); // drain isLoggedIn() Future
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'tapping register link navigates to RegisterScreen',
      (tester) async {
    await _pump(tester, authService: _FakeAuthService(loggedIn: false));
    await tester.pump(); // → LoginScreen

    await tester.tap(find.byKey(const Key('register_link')));
    await tester.pump(); // setState → RegisterScreen
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets(
      'tapping login link on RegisterScreen returns to LoginScreen',
      (tester) async {
    await _pump(tester, authService: _FakeAuthService(loggedIn: false));
    await tester.pump(); // → LoginScreen

    // Go to RegisterScreen
    await tester.tap(find.byKey(const Key('register_link')));
    await tester.pump();
    expect(find.byType(RegisterScreen), findsOneWidget);

    // Go back via login link
    await tester.tap(find.byKey(const Key('login_link')));
    await tester.pump(); // setState → LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  // ── Authenticated routing ──────────────────────────────────────────────────

  testWidgets('shows MainShell when already logged in', (tester) async {
    await _pump(tester, authService: _FakeAuthService(loggedIn: true));
    await tester.pump(); // drain isLoggedIn() Future
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byKey(const Key('bottom_nav_bar')), findsOneWidget);
  });

  testWidgets('successful login transitions to MainShell', (tester) async {
    await _pump(tester, authService: _FakeAuthService(loggedIn: false));
    await tester.pump(); // → LoginScreen

    // Fill and submit the login form
    await tester.enterText(
        find.byKey(const Key('identifier_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'Password1!');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump(); // start login
    await tester.pump(); // complete login + setState

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byKey(const Key('bottom_nav_bar')), findsOneWidget);
  });

  testWidgets('successful registration transitions to MainShell', (tester) async {
    await _pump(tester, authService: _FakeAuthService(loggedIn: false));
    await tester.pump(); // → LoginScreen

    // Navigate to RegisterScreen
    await tester.tap(find.byKey(const Key('register_link')));
    await tester.pump(); // → RegisterScreen

    // Fill and submit the register form
    await tester.enterText(
        find.byKey(const Key('full_name_field')), 'Test Player');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'Password1!');
    await tester.tap(find.byKey(const Key('register_button')));
    await tester.pump(); // start register
    await tester.pump(); // complete register + setState

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byKey(const Key('bottom_nav_bar')), findsOneWidget);
  });

  // ── Logout routing ─────────────────────────────────────────────────────────

  testWidgets('logout transitions back to LoginScreen', (tester) async {
    await _pump(tester, authService: _FakeAuthService(loggedIn: true));
    await tester.pump(); // → MainShell

    expect(find.byType(MainShell), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pump(); // _onLogout: setState(checking) + await logout()
    await tester.pump(); // setState(unauthenticated) → LoginScreen

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });
}
