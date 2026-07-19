import 'package:flutter/material.dart';

import '../features/auth/models/user_profile.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/matchmaking/services/matchmaking_service.dart';
import '../features/profile/services/change_password_service.dart';
import '../features/profile/services/profile_service.dart';
import '../features/wallet/services/payment_service.dart';
import '../features/wallet/services/wallet_service.dart';
import 'main_shell.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D1A);
const _kPrimary = Color(0xFF6C63FF);

// ─── State enums ─────────────────────────────────────────────────────────────

/// High-level states the gate transitions between.
enum _GateState { checking, unauthenticated, authenticated }

/// Which auth screen to show while in the [_GateState.unauthenticated] state.
enum _AuthView { login, register }

// ─── AuthGate ─────────────────────────────────────────────────────────────────

/// The authentication gate — the single point of entry for the app.
///
/// On mount it calls [AuthService.isLoggedIn] to check for a stored session:
///
/// - **Logged in** → shows [MainShell].
/// - **Not logged in** → shows [LoginScreen].
///
/// Internal routing between [LoginScreen] and [RegisterScreen] is managed
/// entirely through state — no [Navigator] calls are made.  After a successful
/// login or registration, the gate transitions to [MainShell].  When the user
/// logs out from the shell, the gate calls [AuthService.logout] and returns to
/// [LoginScreen].
///
/// All service dependencies are injected through the constructor —
/// no singletons or static references.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.profileService,
    required this.changePasswordService,
    required this.walletService,
    required this.paymentService,
    required this.matchmakingService,
  });

  final AuthService           authService;
  final ProfileService        profileService;
  final ChangePasswordService changePasswordService;
  final WalletService         walletService;
  final PaymentService        paymentService;
  final MatchmakingService    matchmakingService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _GateState _gateState = _GateState.checking;
  _AuthView _authView = _AuthView.login;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // ─── Session check ───────────────────────────────────────────────────────────

  Future<void> _checkSession() async {
    final loggedIn = await widget.authService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _gateState =
          loggedIn ? _GateState.authenticated : _GateState.unauthenticated;
    });
  }

  // ─── Callbacks ───────────────────────────────────────────────────────────────

  /// Called by [LoginScreen] or [RegisterScreen] after a successful auth.
  void _onAuthSuccess(UserProfile _) {
    setState(() => _gateState = _GateState.authenticated);
  }

  /// Called by [LoginScreen] when the user taps the Register link.
  void _onRegisterPressed() {
    setState(() {
      _gateState = _GateState.unauthenticated;
      _authView = _AuthView.register;
    });
  }

  /// Called by [RegisterScreen] when the user taps the Log in link or back.
  void _onLoginPressed() {
    setState(() {
      _gateState = _GateState.unauthenticated;
      _authView = _AuthView.login;
    });
  }

  /// Called by [MainShell] when the user taps the logout button.
  ///
  /// Shows a loading screen while the logout request is in flight, then
  /// transitions to [LoginScreen] regardless of server response (the
  /// [AuthService.logout] implementation always clears local tokens).
  Future<void> _onLogout() async {
    setState(() => _gateState = _GateState.checking);
    await widget.authService.logout();
    if (!mounted) return;
    setState(() {
      _gateState = _GateState.unauthenticated;
      _authView = _AuthView.login;
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_gateState) {
      _GateState.checking => const _LoadingScreen(),
      _GateState.authenticated => MainShell(
          profileService:        widget.profileService,
          changePasswordService: widget.changePasswordService,
          walletService:         widget.walletService,
          paymentService:        widget.paymentService,
          matchmakingService:    widget.matchmakingService,
          onLogout:              _onLogout,
        ),
      _GateState.unauthenticated => switch (_authView) {
          _AuthView.login => LoginScreen(
              authService: widget.authService,
              onLoginSuccess: _onAuthSuccess,
              onRegisterPressed: _onRegisterPressed,
            ),
          _AuthView.register => RegisterScreen(
              authService: widget.authService,
              onRegisterSuccess: _onAuthSuccess,
              onLoginPressed: _onLoginPressed,
            ),
        },
    };
  }
}

// ─── Loading screen ───────────────────────────────────────────────────────────

/// Shown while [AuthGate] is determining the session state (initial check or
/// logout in progress).
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: CircularProgressIndicator(
          key: Key('auth_gate_loading'),
          color: _kPrimary,
        ),
      ),
    );
  }
}
