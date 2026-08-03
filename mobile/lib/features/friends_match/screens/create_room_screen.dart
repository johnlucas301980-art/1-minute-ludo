import 'package:flutter/material.dart';

import 'room_lobby_screen.dart';

// ─── Dark arcade palette (matches app theme) ──────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Create Room screen — UI only, no backend or Socket.IO logic.
///
/// Collects room settings (privacy, optional name) and shows a placeholder
/// message when Create Room is pressed.  Room creation will be wired up in a
/// later step.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  bool   _isPublic  = true;
  final  _nameCtrl  = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onCreateRoom() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const RoomLobbyScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Create Room',
          style: TextStyle(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Entry Fee ─────────────────────────────────────────────────
            _SectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Entry Fee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kBorder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '— pts',
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Room Privacy ──────────────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room Privacy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PrivacyToggle(
                          key: const Key('privacy_public'),
                          label: 'Public',
                          icon: Icons.public,
                          selected: _isPublic,
                          onTap: () => setState(() => _isPublic = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrivacyToggle(
                          key: const Key('privacy_private'),
                          label: 'Private',
                          icon: Icons.lock_outline,
                          selected: !_isPublic,
                          onTap: () => setState(() => _isPublic = false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Room Name ─────────────────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Optional',
                    style: TextStyle(color: _kTextSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('room_name_field'),
                    controller: _nameCtrl,
                    maxLength: 32,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      counterStyle:
                          const TextStyle(color: _kTextSecondary),
                      hintText: 'e.g. Friday Night Ludo',
                      hintStyle:
                          const TextStyle(color: _kTextSecondary),
                      filled: true,
                      fillColor: _kBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _kPrimary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Max Players ───────────────────────────────────────────────
            _SectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Max Players',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kBorder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Create Room button ────────────────────────────────────────
            ElevatedButton(
              key: const Key('create_room_button'),
              onPressed: _onCreateRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text('Create Room'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section card wrapper ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

// ─── Privacy toggle tile ──────────────────────────────────────────────────────

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String   label;
  final IconData icon;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _kPrimary.withOpacity(0.15) : _kBg,
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? _kPrimary : _kTextSecondary, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _kPrimary : _kTextSecondary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
