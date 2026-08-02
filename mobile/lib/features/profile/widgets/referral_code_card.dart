import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Dark arcade palette (consistent with ProfileScreen) ─────────────────────
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold = Color(0xFFFFD700);
const _kBorder = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);

/// Displays the player's unique referral code with a one-tap copy button.
///
/// Shows nothing when [referralCode] is null (e.g. on auth-response profiles
/// that do not include the field).
class ReferralCodeCard extends StatelessWidget {
  const ReferralCodeCard({super.key, required this.referralCode});

  final String? referralCode;

  @override
  Widget build(BuildContext context) {
    final code = referralCode;
    if (code == null || code.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label ────────────────────────────────────────────────────────
          const Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: _kGold, size: 16),
              SizedBox(width: 8),
              Text(
                'YOUR REFERRAL CODE',
                style: TextStyle(
                  color: _kGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Code + Copy button ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromRGBO(108, 99, 255, 0.35),
                    ),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CopyButton(code: code),
            ],
          ),
          const SizedBox(height: 10),

          // ── Hint ──────────────────────────────────────────────────────────
          const Text(
            'Share this code with friends to earn rewards.',
            style: TextStyle(color: _kTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Copy button ──────────────────────────────────────────────────────────────

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});
  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _copied
          ? _iconBtn(
              key: const ValueKey('check'),
              icon: Icons.check_rounded,
              color: const Color(0xFF4CAF50),
              label: 'Copied',
            )
          : _iconBtn(
              key: const ValueKey('copy'),
              icon: Icons.copy_rounded,
              color: _kPrimary,
              label: 'Copy',
            ),
    );
  }

  Widget _iconBtn({
    required Key key,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return GestureDetector(
      key: key,
      onTap: _copied ? null : _copy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
