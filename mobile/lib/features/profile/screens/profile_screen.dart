import 'package:flutter/material.dart';
import '../../../core/errors/api_exception.dart';
import '../../auth/models/user_profile.dart';
import '../services/change_password_service.dart';
import '../services/profile_service.dart';
import '../widgets/change_password_sheet.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_info_tile.dart';
import '../widgets/profile_status_badge.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold = Color(0xFFFFD700);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Displays an authenticated player's profile.
///
/// Manages three states — loading, error, and data — with a pull-to-refresh
/// gesture to reload from the server.  Both the Edit Profile and Change
/// Password interactions open modal bottom sheets so that navigation state
/// stays clean.
///
/// All service dependencies are injected through the constructor — no
/// singletons or static references.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profileService,
    required this.changePasswordService,
  });

  final ProfileService profileService;
  final ChangePasswordService changePasswordService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ─── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await widget.profileService.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to the server. Please try again.';
          _loading = false;
        });
      }
    }
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _openEditProfile() {
    if (_profile == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(
        profile: _profile!,
        profileService: widget.profileService,
        onSuccess: (updated) {
          setState(() => _profile = updated);
          _showSnack('Profile updated successfully.');
        },
      ),
    );
  }

  void _openChangePassword() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangePasswordSheet(
        changePasswordService: widget.changePasswordService,
        onSuccess: () =>
            _showSnack('Password changed. Other devices signed out.'),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _kSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: _kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _LoadingView(key: ValueKey('loading'));
    if (_error != null) {
      return _ErrorView(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: _loadProfile,
      );
    }
    return _ProfileView(
      key: const ValueKey('profile'),
      profile: _profile!,
      onRefresh: _loadProfile,
      onEditProfile: _openEditProfile,
      onChangePassword: _openChangePassword,
    );
  }
}

// ─── Loading view ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _kPrimary),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 60,
              color: _kTextSecondary,
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not load profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile view ─────────────────────────────────────────────────────────────

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    super.key,
    required this.profile,
    required this.onRefresh,
    required this.onEditProfile,
    required this.onChangePassword,
  });

  final UserProfile profile;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kPrimary,
      backgroundColor: _kSurface,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ────────────────────────────────────────────────────
            ProfileAvatar(
              avatarUrl: profile.avatar,
              fullName: profile.fullName,
            ),
            const SizedBox(height: 18),

            // ── Full name ─────────────────────────────────────────────────
            Text(
              profile.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),

            // ── Player ID pill ────────────────────────────────────────────
            _PlayerIdPill(playerId: profile.playerId),
            const SizedBox(height: 10),

            // ── Status badge ──────────────────────────────────────────────
            ProfileStatusBadge(status: profile.status),
            const SizedBox(height: 30),

            // ── Info card ─────────────────────────────────────────────────
            _InfoCard(profile: profile),
            const SizedBox(height: 24),

            // ── Action: Edit Profile ──────────────────────────────────────
            _PrimaryButton(
              key: const Key('edit_profile_button'),
              label: 'Edit Profile',
              icon: Icons.edit_rounded,
              onPressed: onEditProfile,
            ),
            const SizedBox(height: 12),

            // ── Action: Change Password ───────────────────────────────────
            _SecondaryButton(
              key: const Key('change_password_button'),
              label: 'Change Password',
              icon: Icons.lock_reset_rounded,
              onPressed: onChangePassword,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Player ID pill ───────────────────────────────────────────────────────────

class _PlayerIdPill extends StatelessWidget {
  const _PlayerIdPill({required this.playerId});
  final String playerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 215, 0, 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(255, 215, 0, 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_esports_rounded, size: 14, color: _kGold),
          const SizedBox(width: 6),
          Text(
            playerId,
            style: const TextStyle(
              color: _kGold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    void addTile(String label, String value, IconData icon) {
      if (tiles.isNotEmpty) {
        tiles.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _kBorder),
          ),
        );
      }
      tiles.add(ProfileInfoTile(label: label, value: value, icon: icon));
    }

    if (profile.email != null && profile.email!.isNotEmpty) {
      addTile('EMAIL', profile.email!, Icons.email_outlined);
    }
    if (profile.mobile != null && profile.mobile!.isNotEmpty) {
      addTile('MOBILE', profile.mobile!, Icons.phone_outlined);
    }
    addTile(
      'COUNTRY',
      (profile.country?.isNotEmpty ?? false) ? profile.country! : 'Not set',
      Icons.flag_outlined,
    );
    if (profile.updatedAt != null) {
      addTile(
        'LAST UPDATED',
        _formatDate(profile.updatedAt!),
        Icons.update_rounded,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tiles,
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year;
      final mo = _p(dt.month);
      final d = _p(dt.day);
      final h = _p(dt.hour);
      final mi = _p(dt.minute);
      return '$y-$mo-$d  $h:$mi';
    } catch (_) {
      return iso;
    }
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ─── Buttons ──────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kPrimary,
          side: const BorderSide(color: _kPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
