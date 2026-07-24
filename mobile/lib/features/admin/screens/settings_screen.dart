import 'package:flutter/material.dart';

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
    try {
      final updated = await widget.adminService.updateSetting(setting.key, value);
      if (mounted) {
        setState(() {
          _settings = _settings.map((item) => item.key == updated.key ? updated : item).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setting updated.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update setting.'), backgroundColor: Colors.red),
        );
      }
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
    return RefreshIndicator(
      onRefresh: _load,
      color: _kSettingsPrimary,
      child: ListView.separated(
        key: const Key('settings_list'),
        padding: const EdgeInsets.all(12),
        itemCount: _settings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final setting = _settings[index];
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
        },
      ),
    );
  }
}