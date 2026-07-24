import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/services/auth_service.dart';
import 'features/game/services/game_service.dart';
import 'features/history/services/history_service.dart';
import 'features/leaderboard/services/leaderboard_service.dart';
import 'features/matchmaking/services/game_lobby_service.dart';
import 'features/matchmaking/services/matchmaking_service.dart';
import 'features/matchmaking/services/socket_client.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/profile/services/change_password_service.dart';
import 'features/support/services/support_service.dart';
import 'features/profile/services/profile_service.dart';
import 'features/wallet/services/payment_service.dart';
import 'features/wallet/services/wallet_service.dart';
import 'navigation/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Shared infrastructure ────────────────────────────────────────────────────
  final storage   = TokenStorage();
  final apiClient = ApiClient(tokenStorage: storage);

  // ── Realtime infrastructure ──────────────────────────────────────────────────
  final socketClient = SocketClient(
    tokenProvider: storage.getAccessToken,
  );
  final notificationSocketClient = SocketClient(
    tokenProvider: storage.getAccessToken,
  );

  // ── Services — constructor DI, no singletons ─────────────────────────────────
  runApp(
    OneLudoApp(
      authService:           AuthService(apiClient: apiClient, tokenStorage: storage),
      profileService:        ProfileService(apiClient: apiClient),
      changePasswordService: ChangePasswordService(apiClient: apiClient),
      walletService:         WalletService(apiClient: apiClient),
      paymentService:        PaymentService(apiClient: apiClient),
      matchmakingService:    MatchmakingService(
        apiClient:    apiClient,
        socketClient: socketClient,
      ),
      gameLobbyService:      GameLobbyService(socketClient: socketClient),
      gameService:           GameService(socketClient: socketClient),
      notificationService:   NotificationService(
        apiClient:    apiClient,
        socketClient: notificationSocketClient,
      ),
      supportService:        SupportService(apiClient: apiClient),
      historyService:        HistoryService(apiClient: apiClient),
      leaderboardService:    LeaderboardService(apiClient: apiClient),
    ),
  );
}

/// Root application widget for 1 Minute Ludo.
///
/// Accepts all top-level service dependencies and passes them to [AuthGate],
/// which manages auth state and routes to either the auth screens or the
/// navigation shell.
class OneLudoApp extends StatelessWidget {
  const OneLudoApp({
    super.key,
    required this.authService,
    required this.profileService,
    required this.changePasswordService,
    required this.walletService,
    required this.paymentService,
    required this.matchmakingService,
    required this.gameLobbyService,
    required this.gameService,
    this.notificationService,
    this.supportService,
    required this.historyService,
    required this.leaderboardService,
  });

  final AuthService           authService;
  final ProfileService        profileService;
  final ChangePasswordService changePasswordService;
  final WalletService         walletService;
  final PaymentService        paymentService;
  final MatchmakingService    matchmakingService;
  final GameLobbyService      gameLobbyService;
  final GameService           gameService;
  final NotificationService?  notificationService;
  final SupportService?       supportService;
  final HistoryService        historyService;
  final LeaderboardService    leaderboardService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1 Minute Ludo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),
        useMaterial3: true,
      ),
      home: AuthGate(
        authService:           authService,
        profileService:        profileService,
        changePasswordService: changePasswordService,
        walletService:         walletService,
        paymentService:        paymentService,
        matchmakingService:    matchmakingService,
        gameLobbyService:      gameLobbyService,
        gameService:           gameService,
        notificationService:   notificationService,
        supportService:        supportService,
        historyService:        historyService,
        leaderboardService:    leaderboardService,
      ),
    );
  }
}
