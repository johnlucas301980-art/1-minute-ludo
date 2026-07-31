import 'package:flutter/material.dart';

import '../models/admin_country.dart';
import '../services/admin_country_service.dart';
import '../widgets/country_tile.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminCountryScreen extends StatefulWidget {
  const AdminCountryScreen({super.key, required this.countryService});

  final AdminCountryService countryService;

  @override
  State<AdminCountryScreen> createState() => _AdminCountryScreenState();
}

class _AdminCountryScreenState extends State<AdminCountryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  List<AdminCountry> _countries = [];
  bool _loading = true;
  String? _error;

  List<AdminCountry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _countries;
    return _countries.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.iso2.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final countries = await widget.countryService.getCountries();
      if (mounted) {
        setState(() {
          _countries = countries;
          _loading = false;
        });
      }
    } on AdminCountryServiceException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.statusCode != null
              ? 'Failed to load countries (${e.statusCode}).'
              : 'Network error. Check your connection.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'An unexpected error occurred.';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('admin_country_screen'),
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text(
          'Country Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text(
                  '${_countries.length} Countries',
                  style: const TextStyle(color: _kGold, fontSize: 11),
                ),
                backgroundColor: _kBg,
                side: const BorderSide(color: _kBorder),
                padding: EdgeInsets.zero,
              ),
            ),
          IconButton(
            key: const Key('country_refresh_button'),
            icon: const Icon(Icons.refresh, color: _kGold),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Container(
            color: _kSurface,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              key: const Key('country_search_field'),
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              enabled: !_loading && _error == null,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name or ISO2…',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        key: const Key('country_search_clear'),
                        icon: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kPrimary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: _kBorder, width: 0.5),
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('country_loading'),
          color: _kPrimary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        key: const Key('country_error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off,
                  color: Colors.white24, size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('country_retry_button'),
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;

    if (filtered.isEmpty) {
      return Center(
        key: const Key('country_empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public_off,
                color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty
                  ? 'No countries match "$_query"'
                  : 'No countries available.',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView.separated(
        key: const Key('country_list'),
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => CountryTile(
          key: Key('country_tile_${filtered[i].iso2}'),
          country: filtered[i],
        ),
      ),
    );
  }
}
