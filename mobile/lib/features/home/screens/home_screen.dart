import 'package:flutter/material.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Home Lobby screen — the main menu shown after a successful login.
///
/// Presents the full game menu:
///   1. Online Match          — triggers matchmaking via [onOnlineMatch]
///   2. Friends Match         — Coming Soon placeholder
///   3. 1 Minute Mode         — disabled, Coming Soon
///   4. Profile               — switches to the Profile tab via [onProfile]
///   5. Points History        — Coming Soon placeholder
///   6. Rules                 — Coming Soon placeholder
///   7. Support               — Coming Soon placeholder
///   8. About                 — Coming Soon placeholder
///   9. Logout                — calls [onLogout]
///
/// No service dependencies — all actions are delegated via callbacks.
class HomeLobbyScreen extends StatelessWidget {
  const HomeLobbyScreen({
    super.key,
    required this.onOnlineMatch,
    required this.onProfile,
    required this.onLogout,
  });

  /// Called when the player taps Online Match.  The parent shell is
  /// responsible for pushing [MatchmakingScreen].
  final VoidCallback onOnlineMatch;

  /// Called when the player taps Profile.  The parent shell switches the
  /// active bottom-navigation tab to the Profile tab.
  final VoidCallback onProfile;

  /// Called when the player taps Logout.  The parent shell handles session
  /// teardown and routing back to the login screen.
  final VoidCallback onLogout;

  void _pushComingSoon(BuildContext context, String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ComingSoonScreen(title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Logo / title ─────────────────────────────────────────────
              const Icon(
                Icons.sports_esports,
                key: Key('home_icon'),
                color: _kGold,
                size: 64,
              ),
              const SizedBox(height: 12),
              const Text(
                '1 Minute Ludo',
                key: Key('home_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your game mode',
                key: Key('home_tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // ── Game modes ───────────────────────────────────────────────
              _MenuItem(
                key: const Key('menu_online_match'),
                icon: Icons.public,
                label: 'Online Match',
                onTap: onOnlineMatch,
              ),
              _MenuItem(
                key: const Key('menu_friends_match'),
                icon: Icons.group_outlined,
                label: 'Friends Match',
                onTap: () => _pushComingSoon(context, 'Friends Match'),
              ),
              _MenuItem(
                key: const Key('menu_1_minute_mode'),
                icon: Icons.timer_outlined,
                label: '1 Minute Mode',
                subtitle: 'Coming Soon',
                enabled: false,
                onTap: null,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: _kBorder, height: 1),
              ),

              // ── Account & info ───────────────────────────────────────────
              _MenuItem(
                key: const Key('menu_profile'),
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: onProfile,
              ),
              _MenuItem(
                key: const Key('menu_points_history'),
                icon: Icons.bar_chart_outlined,
                label: 'Points History',
                onTap: () => _pushComingSoon(context, 'Points History'),
              ),
              _MenuItem(
                key: const Key('menu_rules'),
                icon: Icons.menu_book_outlined,
                label: 'Rules',
                onTap: () => _pushComingSoon(context, 'Rules'),
              ),
              _MenuItem(
                key: const Key('menu_support'),
                icon: Icons.help_outline,
                label: 'Support',
                onTap: () => _pushComingSoon(context, 'Support'),
              ),
              _MenuItem(
                key: const Key('menu_about'),
                icon: Icons.info_outline,
                label: 'About',
                onTap: () => _pushComingSoon(context, 'About'),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: _kBorder, height: 1),
              ),

              // ── Logout ───────────────────────────────────────────────────
              _MenuItem(
                key: const Key('menu_logout'),
                icon: Icons.logout,
                label: 'Logout',
                onTap: onLogout,
                destructive: true,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Coming Soon placeholder screen ──────────────────────────────────────────

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: _kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        iconTheme: const IconThemeData(color: _kTextSecondary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: const Center(
        child: Text(
          'Coming Soon',
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 20,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

// ─── Reusable menu item tile ──────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData      icon;
  final String        label;
  final String?       subtitle;
  final VoidCallback? onTap;
  final bool          enabled;
  final bool          destructive;

  @override
  Widget build(BuildContext context) {
    final labelColor = destructive
        ? Colors.redAccent
        : enabled
            ? Colors.white
            : _kTextSecondary;
    final iconColor = destructive
        ? Colors.redAccent
        : enabled
            ? _kPrimary
            : _kTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: _kTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SOON',
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (!destructive)
                  const Icon(Icons.chevron_right, color: _kTextSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
