import 'package:flutter/material.dart';

import '../features/home/screens/home_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/services/change_password_service.dart';
import '../features/profile/services/profile_service.dart';
import '../features/wallet/screens/wallet_screen.dart';
import '../features/wallet/services/payment_service.dart';
import '../features/wallet/services/wallet_service.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold = Color(0xFFFFD700);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Per-tab display labels — index matches the tab index.
const _kTabLabels = ['Home', 'Profile', 'Wallet'];

/// Navigation shell shown after a successful login or registration.
///
/// Hosts three tabs via a [BottomNavigationBar]:
///
/// - **Home** (index 0) — game lobby placeholder ([HomeScreen])
/// - **Profile** (index 1) — player profile ([ProfileScreen])
/// - **Wallet** (index 2) — wallet and payments ([WalletScreen])
///
/// An [IndexedStack] preserves each screen's scroll and load state across
/// tab switches.  The AppBar title updates to reflect the active tab.
///
/// The AppBar trailing **logout** [IconButton] fires [onLogout]; the parent
/// ([AuthGate]) is responsible for clearing the session and routing back to
/// the auth screens.
///
/// All service dependencies are injected through the constructor —
/// no singletons or static references.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.profileService,
    required this.changePasswordService,
    required this.walletService,
    required this.paymentService,
    required this.onLogout,
  });

  final ProfileService profileService;
  final ChangePasswordService changePasswordService;
  final WalletService walletService;
  final PaymentService paymentService;

  /// Called when the user taps the logout button.
  /// The parent is responsible for performing the logout and re-routing.
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _onTabTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        key: const Key('main_shell_app_bar'),
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          _kTabLabels[_selectedIndex],
          style: const TextStyle(
            color: _kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('logout_button'),
            icon: const Icon(Icons.logout, color: _kTextSecondary),
            tooltip: 'Log out',
            onPressed: widget.onLogout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: IndexedStack(
        key: const Key('main_shell_body'),
        index: _selectedIndex,
        children: [
          const HomeScreen(),
          ProfileScreen(
            profileService: widget.profileService,
            changePasswordService: widget.changePasswordService,
          ),
          WalletScreen(
            walletService: widget.walletService,
            paymentService: widget.paymentService,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        key: const Key('bottom_nav_bar'),
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        backgroundColor: _kSurface,
        selectedItemColor: _kPrimary,
        unselectedItemColor: _kTextSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports_outlined),
            activeIcon: Icon(Icons.sports_esports),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
        ],
      ),
    );
  }
}
