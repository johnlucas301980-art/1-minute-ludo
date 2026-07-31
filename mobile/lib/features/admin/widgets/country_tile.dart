import 'package:flutter/material.dart';

import '../models/admin_country.dart';

// ─── Shared palette ──────────────────────────────────────────────────────────
const _kSurface  = Color(0xFF1A1A2E);
const _kPrimary  = Color(0xFF6C63FF);
const _kGold     = Color(0xFFFFD700);
const _kBorder   = Color(0xFF2D2D4E);

// ─── Local permission state (not yet wired to the API) ───────────────────────

class CountryPermissions {
  const CountryPermissions({
    this.registration = true,
    this.login        = true,
    this.gameplay     = true,
    this.recharge     = true,
    this.withdraw     = true,
    this.tournament   = true,
  });

  final bool registration;
  final bool login;
  final bool gameplay;
  final bool recharge;
  final bool withdraw;
  final bool tournament;

  CountryPermissions copyWith({
    bool? registration,
    bool? login,
    bool? gameplay,
    bool? recharge,
    bool? withdraw,
    bool? tournament,
  }) =>
      CountryPermissions(
        registration: registration ?? this.registration,
        login:        login        ?? this.login,
        gameplay:     gameplay     ?? this.gameplay,
        recharge:     recharge     ?? this.recharge,
        withdraw:     withdraw     ?? this.withdraw,
        tournament:   tournament   ?? this.tournament,
      );
}

// ─── Flag helper ──────────────────────────────────────────────────────────────

String _flagEmoji(String iso2) {
  const base = 0x1F1E6 - 0x41; // 'A' = 0x41
  final upper = iso2.toUpperCase();
  return String.fromCharCode(base + upper.codeUnitAt(0)) +
      String.fromCharCode(base + upper.codeUnitAt(1));
}

// ─── CountryTile ─────────────────────────────────────────────────────────────

class CountryTile extends StatefulWidget {
  const CountryTile({
    super.key,
    required this.country,
    this.initialPermissions = const CountryPermissions(),
    this.onPermissionsChanged,
  });

  final AdminCountry country;
  final CountryPermissions initialPermissions;

  /// Called with the updated [CountryPermissions] whenever a switch is toggled.
  final void Function(CountryPermissions)? onPermissionsChanged;

  @override
  State<CountryTile> createState() => _CountryTileState();
}

class _CountryTileState extends State<CountryTile> {
  late CountryPermissions _perms;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _perms = widget.initialPermissions;
  }

  void _toggle(_Field field, bool value) {
    setState(() {
      _perms = switch (field) {
        _Field.registration => _perms.copyWith(registration: value),
        _Field.login        => _perms.copyWith(login: value),
        _Field.gameplay     => _perms.copyWith(gameplay: value),
        _Field.recharge     => _perms.copyWith(recharge: value),
        _Field.withdraw     => _perms.copyWith(withdraw: value),
        _Field.tournament   => _perms.copyWith(tournament: value),
      };
    });
    widget.onPermissionsChanged?.call(_perms);
  }

  @override
  Widget build(BuildContext context) {
    final flag = _flagEmoji(widget.country.iso2);

    return Card(
      key: Key('country_tile_${widget.country.iso2}'),
      color: _kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _expanded ? _kPrimary : _kBorder,
          width: _expanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────────
          InkWell(
            key: Key('country_tile_header_${widget.country.iso2}'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Flag
                  Text(
                    flag,
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(width: 12),
                  // Name + ISO2
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.country.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.country.iso2.toUpperCase(),
                          style: const TextStyle(
                            color: _kGold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.country.isActive
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.country.isActive
                            ? Colors.green
                            : Colors.redAccent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      widget.country.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: widget.country.isActive
                            ? Colors.green
                            : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white38, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Switches panel ────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? _SwitchesPanel(perms: _perms, onToggle: _toggle)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Switches panel ───────────────────────────────────────────────────────────

enum _Field { registration, login, gameplay, recharge, withdraw, tournament }

class _SwitchesPanel extends StatelessWidget {
  const _SwitchesPanel({required this.perms, required this.onToggle});

  final CountryPermissions perms;
  final void Function(_Field, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_registration'),
                  label: 'Registration',
                  icon: Icons.person_add_outlined,
                  value: perms.registration,
                  onChanged: (v) => onToggle(_Field.registration, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_login'),
                  label: 'Login',
                  icon: Icons.login_outlined,
                  value: perms.login,
                  onChanged: (v) => onToggle(_Field.login, v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_gameplay'),
                  label: 'Gameplay',
                  icon: Icons.sports_esports_outlined,
                  value: perms.gameplay,
                  onChanged: (v) => onToggle(_Field.gameplay, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_recharge'),
                  label: 'Recharge',
                  icon: Icons.add_card_outlined,
                  value: perms.recharge,
                  onChanged: (v) => onToggle(_Field.recharge, v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_withdraw'),
                  label: 'Withdraw',
                  icon: Icons.account_balance_wallet_outlined,
                  value: perms.withdraw,
                  onChanged: (v) => onToggle(_Field.withdraw, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_tournament'),
                  label: 'Tournament',
                  icon: Icons.emoji_events_outlined,
                  value: perms.tournament,
                  onChanged: (v) => onToggle(_Field.tournament, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: value ? _kPrimary : Colors.white30),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: value ? Colors.white70 : Colors.white30,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _kPrimary,
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
          ),
        ),
      ],
    );
  }
}
