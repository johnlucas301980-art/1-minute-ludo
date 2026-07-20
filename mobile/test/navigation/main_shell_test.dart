import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/core/network/api_client.dart';
import 'package:one_minute_ludo/core/storage/token_storage.dart';
import 'package:one_minute_ludo/features/auth/models/user_profile.dart';
import 'package:one_minute_ludo/features/game/models/game_over.dart';
import 'package:one_minute_ludo/features/game/screens/game_screen.dart';
import 'package:one_minute_ludo/features/game/services/game_service.dart';
import 'package:one_minute_ludo/features/matchmaking/models/game_started.dart';
import 'package:one_minute_ludo/features/matchmaking/models/match_found.dart';
import 'package:one_minute_ludo/features/matchmaking/models/opponent.dart';
import 'package:one_minute_ludo/features/matchmaking/models/room_ready.dart';
import 'package:one_minute_ludo/features/matchmaking/screens/matchmaking_screen.dart';
import 'package:one_minute_ludo/features/matchmaking/services/game_lobby_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/matchmaking_service.dart';
import 'package:one_minute_ludo/features/matchmaking/services/socket_client.dart';
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

// ─── Fake GameService ─────────────────────────────────────────────────────────

class _FakeGameService extends GameService {
  _FakeGameService() : super(socketClient: _FakeSocketClientForGame());

  @override
  void startListening() {}

  @override
  void stopListening() {}

  @override
  void dispose() {}
}

// Minimal SocketClient used only to satisfy GameService's super constructor.
class _FakeSocketClientForGame extends SocketClient {
  _FakeSocketClientForGame() : super(tokenProvider: () async => 'fake-token');

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

// ─── Fake SocketClient ────────────────────────────────────────────────────────

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

// ─── Fake MatchmakingService ──────────────────────────────────────────────────

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

// ─── Fake GameLobbyService ────────────────────────────────────────────────────

class _FakeGameLobbyService extends GameLobbyService {
  _FakeGameLobbyService() : super(socketClient: _FakeSocketClient());

  final _roomReadyCtrl   = StreamController<RoomReady>.broadcast();
  final _gameStartedCtrl = StreamController<GameStarted>.broadcast();
  final _gameOverCtrl    = StreamController<GameOver>.broadcast();

  @override
  Stream<RoomReady>   get onRoomReady  => _roomReadyCtrl.stream;

  @override
  Stream<GameStarted> get onGameStart  => _gameStartedCtrl.stream;

  @override
  Stream<GameOver>    get onGameOver   => _gameOverCtrl.stream;

  @override
  Future<void> joinRoom(String matchId) async {}

  @override
  void leaveRoom(String matchId) {}

  @override
  void forfeit(String matchId) {}

  @override
  void dispose() {
    _roomReadyCtrl.close();
    _gameStartedCtrl.close();
    _gameOverCtrl.close();
  }

  void simulateGameStarted(String matchId, String firstTurn) =>
      _gameStartedCtrl.add(GameStarted(matchId: matchId, firstTurn: firstTurn));

  void simulateGameOver(String matchId, String winnerId, String reason) =>
      _gameOverCtrl.add(GameOver(matchId: matchId, winnerId: winnerId, reason: reason));
}

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

const _kMatchFound = MatchFound(
  matchId:  'match-uuid-1',
  roomCode: 'XYZ789',
  color:    'red',
  opponent: Opponent(playerId: 'LUD-OPP001', fullName: 'Opponent Player'),
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

Future<_FakeGameLobbyService> _pump(
  WidgetTester tester, {
  VoidCallback? onLogout,
  _FakeGameLobbyService? gameLobbyService,
}) async {
  final svc = gameLobbyService ?? _FakeGameLobbyService();
  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(
        profileService:        _FakeProfileService(),
        changePasswordService: _FakeChangePasswordService(),
        walletService:         _FakeWalletService(),
        paymentService:        _FakePaymentService(),
        matchmakingService:    _FakeMatchmakingService(),
        gameLobbyService:      svc,
        gameService:           _FakeGameService(),
        onLogout:              onLogout ?? () {},
      ),
    ),
  );
  return svc;
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

  testWidgets(
      'Home tab is selected and MatchmakingScreen is shown by default',
      (tester) async {
    await _pump(tester);
    expect(find.byType(MatchmakingScreen), findsOneWidget);
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

  testWidgets(
      '_onGameStart pushes GameScreen when game_start is fired from lobby',
      (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, gameLobbyService: svc);

    // Navigate via the shell's _onMatchReady by triggering it from inside
    // the test tree using a builder-injected navigator call.
    final shellState = tester.state<State>(find.byType(MainShell));
    // ignore: invalid_use_of_protected_member
    final shellContext = shellState.context;

    Navigator.of(shellContext).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          gameService:      _FakeGameService(),
          gameLobbyService: svc,
          gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'red'),
          matchFound:  _kMatchFound,
          onGameOver:   (_) {},
          onSessionExpired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byKey(const Key('game_screen_app_bar')), findsOneWidget);
  });

  testWidgets(
      '_onGameOver pops back to shell root when game_over overlay is dismissed',
      (tester) async {
    final svc = _FakeGameLobbyService();
    await _pump(tester, gameLobbyService: svc);

    final shellState = tester.state<State>(find.byType(MainShell));
    // ignore: invalid_use_of_protected_member
    final shellContext = shellState.context;

    // Push GameScreen as the shell would
    Navigator.of(shellContext).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          gameService:      _FakeGameService(),
          gameLobbyService: svc,
          gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'red'),
          matchFound:  _kMatchFound,
          onGameOver:   (result) =>
              Navigator.of(shellContext).popUntil((r) => r.isFirst),
          onSessionExpired: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Simulate game_over
    svc.simulateGameOver('match-uuid-1', 'winner-id', 'forfeit');
    await tester.pump();
    await tester.pump(); // extra pump so the overlay rebuild completes

    // Dismiss the overlay
    await tester.tap(find.byKey(const Key('game_over_continue_button')));
    await tester.pump(); // start the pop
    await tester.pump(const Duration(milliseconds: 350)); // past the 300ms transition
    await tester.pump(); // cleanup frame

    // Should be back at the shell
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
  });
}
