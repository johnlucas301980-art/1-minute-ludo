import 'package:flutter/material.dart';

import '../models/admin_country.dart';

// ─── Shared palette ──────────────────────────────────────────────────────────
const _kSurface  = Color(0xFF1A1A2E);
const _kPrimary  = Color(0xFF6C63FF);
const _kGold     = Color(0xFFFFD700);
const _kBorder   = Color(0xFF2D2D4E);

// ─── Permission state ─────────────────────────────────────────────────────────

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

// ─── Switch field enum ────────────────────────────────────────────────────────

enum CountryField {
  registration,
  login,
  gameplay,
  recharge,
  withdraw,
  tournament;

  /// The key sent in the PUT request body.
  String get apiKey => switch (this) {
        CountryField.registration => 'allow_registration',
        CountryField.login        => 'allow_login',
        CountryField.gameplay     => 'allow_gameplay',
        CountryField.recharge     => 'allow_recharge',
        CountryField.withdraw     => 'allow_withdraw',
        CountryField.tournament   => 'allow_tournament',
      };
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
    /// Called when a switch is toggled. Must return [true] if the update
    /// succeeded, [false] if it failed (the tile will revert the switch).
    this.onSwitchToggle,
  });

  final AdminCountry country;
  final CountryPermissions initialPermissions;
  final Future<bool> Function(CountryField field, bool value)? onSwitchToggle;

  @override
  State<CountryTile> createState() => _CountryTileState();
}

class _CountryTileState extends State<CountryTile> {
  late CountryPermissions _perms;
  bool _expanded = false;
  bool _saving   = false;

  @override
  void initState() {
    super.initState();
    _perms = widget.initialPermissions;
  }

  Future<void> _toggle(CountryField field, bool newValue) async {
    if (_saving) return;

    final previous = _perms;

    // Optimistic update — show new value immediately.
    setState(() {
      _perms  = _applyField(_perms, field, newValue);
      _saving = true;
    });

    bool success = false;
    try {
      success = await (widget.onSwitchToggle?.call(field, newValue) ??
          Future.value(true));
    } catch (_) {
      success = false;
    }

    if (!mounted) return;

    if (success) {
      setState(() => _saving = false);
    } else {
      // Rollback to the state before the toggle.
      setState(() {
        _perms  = previous;
        _saving = false;
      });
    }
  }

  static CountryPermissions _applyField(
    CountryPermissions p,
    CountryField field,
    bool v,
  ) =>
      switch (field) {
        CountryField.registration => p.copyWith(registration: v),
        CountryField.login        => p.copyWith(login: v),
        CountryField.gameplay     => p.copyWith(gameplay: v),
        CountryField.recharge     => p.copyWith(recharge: v),
        CountryField.withdraw     => p.copyWith(withdraw: v),
        CountryField.tournament   => p.copyWith(tournament: v),
      };

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.country.isAllowed
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.country.isAllowed
                            ? Colors.green
                            : Colors.redAccent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      widget.country.isAllowed ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: widget.country.isAllowed
                            ? Colors.green
                            : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Saving spinner / expand chevron
                  if (_saving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPrimary,
                      ),
                    )
                  else
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
                ? _SwitchesPanel(
                    perms:    _perms,
                    disabled: _saving,
                    onToggle: _toggle,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Switches panel ───────────────────────────────────────────────────────────

class _SwitchesPanel extends StatelessWidget {
  const _SwitchesPanel({
    required this.perms,
    required this.disabled,
    required this.onToggle,
  });

  final CountryPermissions perms;
  final bool disabled;
  final void Function(CountryField, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_registration'),
                  label:    'Registration',
                  icon:     Icons.person_add_outlined,
                  value:    perms.registration,
                  disabled: disabled,
                  onChanged: (v) => onToggle(CountryField.registration, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_login'),
                  label:    'Login',
                  icon:     Icons.login_outlined,
                  value:    perms.login,
                  disabled: disabled,
                  onChanged: (v) => onToggle(CountryField.login, v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_gameplay'),
                  label:    'Gameplay',
                  icon:     Icons.sports_esports_outlined,
                  value:    perms.gameplay,
                  disabled: disabled,
                  onChanged: (v) => onToggle(CountryField.gameplay, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_recharge'),
                  label:    'Recharge',
                  icon:     Icons.add_card_outlined,
                  value:    perms.recharge,
                  disabled: disabled,
                  onChanged: (v) => onToggle(CountryField.recharge, v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_withdraw'),
                  label:    'Withdraw',
                  icon:     Icons.account_balance_wallet_outlined,
                  value:    perms.withdraw,
                  disabled: disabled,
                  onChanged: (v) => onToggle(CountryField.withdraw, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SwitchRow(
                  key: const Key('switch_tournament'),
                  label:    'Tournament',
                  icon:     Icons.emoji_events_outlined,
                  value:    perms.tournament,
                  disabled: disabled,
                  onChanged: (v) => onToggle(CountryField.tournament, v),
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
    required this.disabled,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size:  14,
            color: disabled
                ? Colors.white12
                : (value ? _kPrimary : Colors.white30)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: disabled
                  ? Colors.white24
                  : (value ? Colors.white70 : Colors.white30),
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value:              value,
            onChanged:          disabled ? null : onChanged,
            activeColor:        _kPrimary,
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
          ),
        ),
      ],
    );
  }
}
