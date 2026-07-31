import 'package:flutter/material.dart';

import '../models/country.dart';

// ─── Dark arcade palette ──────────────────────────────────────────────────────
const _kSurface        = Color(0xFF1A1A2E);
const _kPrimary        = Color(0xFF6C63FF);
const _kBorder         = Color(0xFF2D2D4E);
const _kTextSecondary  = Color(0xFF9E9E9E);
const _kError          = Color(0xFFFF4C4C);
const _kBg             = Color(0xFF0D0D1A);

/// A styled tap-to-pick country selector that matches the app's auth form look.
///
/// Opens a searchable bottom-sheet listing all [countries].
/// Calls [onChanged] when the user selects a different country.
///
/// Pass [errorText] to show a red-border error state below the field.
class CountryPickerField extends StatelessWidget {
  const CountryPickerField({
    super.key,
    required this.countries,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
    this.label = 'Country',
  });

  final List<Country> countries;
  final Country?      selected;
  final ValueChanged<Country> onChanged;
  final bool    enabled;
  final String? errorText;
  final String  label;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: enabled ? () => _openPicker(context) : null,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? _kError
                    : const Color(0xFF2D2D4E),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                if (selected != null) ...[
                  Text(
                    selected!.flagEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${selected!.name}  (${selected!.dialCode})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Icon(
                  Icons.expand_more_rounded,
                  color: hasError ? _kError : _kTextSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: _kError,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        countries: countries,
        selected: selected,
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

// ─── Bottom-sheet picker ──────────────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.countries,
    required this.selected,
  });

  final List<Country> countries;
  final Country?      selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late List<Country> _filtered;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.countries
          : widget.countries.where((c) {
              return c.name.toLowerCase().contains(q) ||
                  c.iso2.toLowerCase().contains(q) ||
                  c.dialCode.contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.80;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Drag handle ───────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ─────────────────────────────────────────────────────────
          const Text(
            'Select Country',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // ── Search box ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search country or dial code…',
                hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _kTextSecondary, size: 20),
                filled: true,
                fillColor: _kSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No countries found.',
                      style: TextStyle(color: _kTextSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, index) {
                      final country = _filtered[index];
                      final isSelected =
                          widget.selected?.iso2 == country.iso2;
                      return ListTile(
                        leading: Text(
                          country.flagEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          country.name,
                          style: TextStyle(
                            color: isSelected ? _kPrimary : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 15,
                          ),
                        ),
                        trailing: Text(
                          country.dialCode,
                          style: const TextStyle(
                            color: _kTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
