import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/models/user_profile.dart';
import 'package:one_minute_ludo/features/auth/screens/login_screen.dart';
import 'package:one_minute_ludo/features/auth/services/auth_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/matchmaking_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';
import 'package:one_minute_ludo/features/profile/services/change_password_service.dart';
import 'package:one_minute_ludo/features/profile/services/profile_service.dart';
import 'package:one_minute_ludo/features/wallet/services/payment_service.dart';
import 'package:one_minute_ludo/features/wallet/services/wallet_service.dart';
import 'package:one_minute_ludo/main.dart';

// ─── Minimal fakes ────────────────────────────────────────────────────────────

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenStorage: const TokenStorage());
}

class _FakeAuthService extends AuthService {
  _FakeAuthService()
      : super(
          apiClient:    _FakeApiClient(),
          tokenStorage: const TokenStorage(),
        );

  @override
  Future<bool> isLoggedIn() async => false; // always unauthenticated

  @override
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) =>
      Completer<UserProfile>().future;
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService() : super(apiClient: _FakeApiClient());

  @override
  Future<UserProfile> getProfile() => Completer<UserProfile>().future;
}

class _FakeChangePasswordService extends ChangePasswordService {
  _FakeChangePasswordService() : super(apiClient: _FakeApiClient());
}

class _FakeWalletService extends WalletService {
  _FakeWalletService() : super(apiClient: _FakeApiClient());
}

class _FakePaymentService extends PaymentService {
  _FakePaymentService() : super(apiClient: _FakeApiClient());
}

class _FakeSocketClient extends SocketClient {
  _FakeSocketClient() : super(tokenProvider: () async => 'fake-token');

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void emit(String event, [dynamic data]) {}

  @override
  void on(String event, void Function(dynamic) handler) {}

  @override
  void off(String event) {}

  @override
  void dispose() {}
}

class _FakeMatchmakingService extends MatchmakingService {
  _FakeMatchmakingService()
      : super(
          apiClient:    _FakeApiClient(),
          socketClient: _FakeSocketClient(),
        );

  @override
  Future<void> joinQueue() async {}

  @override
  Future<void> leaveQueue() async {}
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  testWidgets('App smoke test — renders without crashing', (tester) async {
    await tester.pumpWidget(
      OneLudoApp(
        authService:           _FakeAuthService(),
        profileService:        _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
        walletService:         _FakeWalletService(),
        paymentService:        _FakePaymentService(),
        matchmakingService:    _FakeMatchmakingService(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App shows LoginScreen for unauthenticated users', (tester) async {
    await tester.pumpWidget(
      OneLudoApp(
        authService:           _FakeAuthService(),
        profileService:        _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
        walletService:         _FakeWalletService(),
        paymentService:        _FakePaymentService(),
        matchmakingService:    _FakeMatchmakingService(),
      ),
    );
    await tester.pump(); // drain isLoggedIn() Future → LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
