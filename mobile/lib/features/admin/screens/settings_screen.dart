import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_setting.dart';
import '../services/admin_service.dart';

const _kSettingsBg = Color(0xFF0D0D1A);
const _kSettingsSurface = Color(0xFF1A1A2E);
const _kSettingsPrimary = Color(0xFF6C63FF);
const _kSettingsGold = Color(0xFFFFD700);
const _kSettingsBorder = Color(0xFF2D2D4E);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.adminService});
  final AdminService adminService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<AdminSetting> _settings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final settings = await widget.adminService.listSettings();
      if (mounted) setState(() { _settings = settings; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load settings.'; _loading = false; });
    }
  }

  AdminSetting? _find(String key) {
    try {
      return _settings.firstWhere((s) => s.key == key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateSetting(String key, String value) async {
    try {
      final updated = await widget.adminService.updateSetting(key, value);
      if (mounted) {
        setState(() {
          _settings = _settings.map((item) => item.key == updated.key ? updated : item).toList();
          // Add if not yet present (first-time seed).
          if (!_settings.any((s) => s.key == updated.key)) {
            _settings = [..._settings, updated];
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update setting.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _edit(AdminSetting setting) async {
    final controller = TextEditingController(text: setting.value);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSettingsSurface,
        title: Text('Edit ${setting.key}', style: const TextStyle(color: Colors.white)),
        content: TextField(
          key: const Key('setting_value_field'),
          controller: controller,
          maxLines: 5,
          maxLength: 5000,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Value',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kSettingsBorder)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kSettingsPrimary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const Key('save_setting_button'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    await _updateSetting(setting.key, value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setting updated.')));
    }
  }

  Future<void> _editBonusAmount() async {
    final current = _find('welcome_bonus_amount');
    final controller = TextEditingController(text: current?.value ?? '100');
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSettingsSurface,
        title: const Text('Bonus Amount', style: TextStyle(color: Colors.white)),
        content: TextField(
          key: const Key('bonus_amount_field'),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Points',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kSettingsBorder)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kSettingsPrimary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const Key('save_bonus_amount_button'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    await _updateSetting('welcome_bonus_amount', value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bonus amount updated.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: const Key('settings_screen'),
        backgroundColor: _kSettingsBg,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: _kSettingsSurface,
          actions: [
            IconButton(
              key: const Key('settings_refresh_button'),
              icon: const Icon(Icons.refresh, color: _kSettingsGold),
              onPressed: _load,
            ),
          ],
        ),
        body: _buildBody(),
      );

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('settings_loading'), color: _kSettingsPrimary),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!, key: const Key('settings_error'), style: const TextStyle(color: Colors.white70)));
    }
    if (_settings.isEmpty) {
      return const Center(
        child: Text('No settings configured.', key: Key('settings_empty'), style: TextStyle(color: Colors.white54)),
      );
    }

    // Keys managed by the Welcome Bonus card — excluded from the generic list.
    const _welcomeBonusKeys = {'welcome_bonus_enabled', 'welcome_bonus_amount'};

    final bonusEnabled = _find('welcome_bonus_enabled')?.value == 'true';
    final bonusAmount  = _find('welcome_bonus_amount')?.value ?? '100';
    final otherSettings = _settings.where((s) => !_welcomeBonusKeys.contains(s.key)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: _kSettingsPrimary,
      child: ListView(
        key: const Key('settings_list'),
        padding: const EdgeInsets.all(12),
        children: [

          // ── Welcome Bonus card ──────────────────────────────────────────────
          Card(
            key: const Key('welcome_bonus_card'),
            color: _kSettingsSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: _kSettingsBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WELCOME BONUS',
                    style: TextStyle(
                      color: _kSettingsGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Enable / Disable toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Enable Welcome Bonus', style: TextStyle(color: Colors.white, fontSize: 14)),
                      Switch(
                        key: const Key('welcome_bonus_toggle'),
                        value: bonusEnabled,
                        activeColor: _kSettingsPrimary,
                        onChanged: (val) => _updateSetting('welcome_bonus_enabled', val ? 'true' : 'false'),
                      ),
                    ],
                  ),

                  const Divider(color: _kSettingsBorder, height: 16),

                  // Bonus amount row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bonus Amount (points)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      Row(
                        children: [
                          Text(
                            bonusAmount,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('edit_bonus_amount_button'),
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                            onPressed: _editBonusAmount,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Generic settings ────────────────────────────────────────────────
          ...List.generate(otherSettings.length * 2 - (otherSettings.isEmpty ? 0 : 1), (i) {
            if (i.isOdd) return const SizedBox(height: 8);
            final setting = otherSettings[i ~/ 2];
            return Card(
              key: Key('setting_tile_${setting.key}'),
              color: _kSettingsSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: _kSettingsBorder),
              ),
              child: ListTile(
                title: Text(setting.key, style: const TextStyle(color: _kSettingsGold, fontWeight: FontWeight.bold)),
                subtitle: Text(setting.value, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(
                  key: Key('edit_setting_${setting.key}'),
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, color: Colors.white54),
                  onPressed: () => _edit(setting),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
