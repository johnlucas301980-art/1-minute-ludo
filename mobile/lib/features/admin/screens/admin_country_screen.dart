import 'package:flutter/material.dart';

import '../models/admin_country.dart';
import '../widgets/country_tile.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0D0D1A);
const _kSurface = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);
const _kBorder  = Color(0xFF2D2D4E);

// ─── Mock data (replace with API call in a later phase) ───────────────────────
final _kMockCountries = [
  const AdminCountry(iso2: 'NG', name: 'Nigeria',        isActive: true),
  const AdminCountry(iso2: 'GH', name: 'Ghana',          isActive: true),
  const AdminCountry(iso2: 'KE', name: 'Kenya',          isActive: true),
  const AdminCountry(iso2: 'ZA', name: 'South Africa',   isActive: true),
  const AdminCountry(iso2: 'IN', name: 'India',          isActive: true),
  const AdminCountry(iso2: 'PK', name: 'Pakistan',       isActive: true),
  const AdminCountry(iso2: 'BD', name: 'Bangladesh',     isActive: false),
  const AdminCountry(iso2: 'US', name: 'United States',  isActive: false),
  const AdminCountry(iso2: 'GB', name: 'United Kingdom', isActive: false),
  const AdminCountry(iso2: 'BR', name: 'Brazil',         isActive: true),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminCountryScreen extends StatefulWidget {
  const AdminCountryScreen({super.key});

  @override
  State<AdminCountryScreen> createState() => _AdminCountryScreenState();
}

class _AdminCountryScreenState extends State<AdminCountryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  List<AdminCountry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _kMockCountries;
    return _kMockCountries.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.iso2.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                '${_kMockCountries.length} Countries',
                style: const TextStyle(color: _kGold, fontSize: 11),
              ),
              backgroundColor: _kBg,
              side: const BorderSide(color: _kBorder),
              padding: EdgeInsets.zero,
            ),
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
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name or ISO2…',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        key: const Key('country_search_clear'),
                        icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: _kBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kPrimary),
                ),
              ),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    key: const Key('country_empty'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public_off,
                            color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No countries match "$_query"',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    key: const Key('country_list'),
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => CountryTile(
                      key: Key('country_tile_${filtered[i].iso2}'),
                      country: filtered[i],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
