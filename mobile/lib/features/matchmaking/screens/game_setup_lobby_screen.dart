import 'package:flutter/material.dart';

// ─── Dark arcade palette (matches app theme) ──────────────────────────────────
const _kBg            = Color(0xFF0D0D1A);
const _kSurface       = Color(0xFF1A1A2E);
const _kPrimary       = Color(0xFF6C63FF);
const _kGold          = Color(0xFFFFD700);
const _kBorder        = Color(0xFF2D2D4E);
const _kTextSecondary = Color(0xFF9E9E9E);
const _kGreen         = Color(0xFF4CAF50);

/// Game Setup Lobby — entry-point selection before online matchmaking.
///
/// Presents stake options for the player to choose before searching for
/// an opponent.  Service injection and matchmaking navigation are wired
/// by the parent that pushes this screen.
class GameSetupLobbyScreen extends StatefulWidget {
  const GameSetupLobbyScreen({super.key});

  @override
  State<GameSetupLobbyScreen> createState() => _GameSetupLobbyScreenState();
}

class _GameSetupLobbyScreenState extends State<GameSetupLobbyScreen> {
  int _selectedIndex = 0;

  static const List<_EntryOption> _options = [
    _EntryOption(label: 'Free',  subtitle: 'No stake',   points: 0),
    _EntryOption(label: '₦50',   subtitle: '50 points',  points: 50),
    _EntryOption(label: '₦100',  subtitle: '100 points', points: 100),
    _EntryOption(label: '₦200',  subtitle: '200 points', points: 200),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Game Setup',
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Entry Points',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your stake to enter the match.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ...List.generate(_options.length, (i) {
              final opt      = _options[i];
              final selected = i == _selectedIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  key: Key('entry_option_$i'),
                  onTap: () => setState(() => _selectedIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: selected
                          ? _kPrimary.withValues(alpha: 0.15)
                          : _kSurface,
                      border: Border.all(
                        color: selected ? _kPrimary : _kBorder,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? _kPrimary : Colors.transparent,
                            border: Border.all(
                              color: selected ? _kPrimary : _kTextSecondary,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.label,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : _kTextSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.subtitle,
                                style: const TextStyle(
                                  color: _kTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            ElevatedButton.icon(
              key: const Key('find_match_button'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Matchmaking coming in the next step.'),
                    backgroundColor: _kSurface,
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text(
                'FIND MATCH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _EntryOption {
  const _EntryOption({
    required this.label,
    required this.subtitle,
    required this.points,
  });

  final String label;
  final String subtitle;
  final int    points;
}
