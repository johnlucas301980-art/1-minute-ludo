import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/player_panel_widget.dart';
import '../widgets/premium_ludo_board_widget.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const Color _kBg            = Color(0xFF0D0D1A);
const Color _kSurface       = Color(0xFF1A1A2E);
const Color _kBorder        = Color(0xFF2D2D4E);
const Color _kGold          = Color(0xFFFFD700);
const Color _kTextSecondary = Color(0xFF9E9E9E);
const Color _kGreen         = Color(0xFF4CAF50);

Color _colorForName(String c) => switch (c) {
      'red'    => const Color(0xFFE53935),
      'blue'   => const Color(0xFF1565C0),
      'yellow' => const Color(0xFFF9A825),
      'green'  => const Color(0xFF2E7D32),
      _        => const Color(0xFF6C63FF),
    };

// ─── Mock player data for UI-only phase ──────────────────────────────────────

/// Lightweight player info for the final game UI (no game logic).
class GameUiPlayer {
  const GameUiPlayer({
    required this.name,
    required this.countryFlag,
    required this.playerId,
    required this.color,
    this.avatarUrl,
  });

  final String  name;
  final String  countryFlag;
  final String  playerId;
  final String  color; // 'red' | 'blue' | 'yellow' | 'green'
  final String? avatarUrl;
}

// ─── Board rotation helper ────────────────────────────────────────────────────

/// Returns the board rotation (radians) so that [myColor]'s yard appears at the
/// bottom-left corner of the screen.
///
/// Board natural layout: Red=BL, Blue=TL, Yellow=TR, Green=BR.
///   red    →  0          (already at BL)
///   blue   → -π/2        (CCW: TL → BL)
///   yellow →  π          (180°: TR → BL)
///   green  →  π/2        (CW:  BR → BL)
double boardRotationForColor(String color) => switch (color) {
      'red'    => 0.0,
      'blue'   => -math.pi / 2,
      'yellow' => math.pi,
      'green'  => math.pi / 2,
      _        => 0.0,
    };

// ─── FinalGameScreen ──────────────────────────────────────────────────────────

/// Final production-quality Game UI — Phase: UI Foundation.
///
/// Layout (portrait):
///
///   ┌──[TL panel]────────[TR panel]──┐
///   │                                │
///   │         Ludo Board             │
///   │      (rotated so YOU=BL)       │
///   │                                │
///   │          [🎲 Dice]             │
///   │          YOUR TURN             │
///   │                                │
///   └──[BL panel YOU]──[BR panel]────┘
///
/// No game logic / dice logic / pawn logic is wired here.
/// All data is passed in via [GameUiPlayer] list; default mock data is provided
/// for design-preview purposes.
class FinalGameScreen extends StatefulWidget {
  const FinalGameScreen({
    super.key,
    this.playerCount = 4,
    this.myColor     = 'red',
    this.currentTurn = 'red',
    this.players,
    this.onBack,
  });

  /// How many players are in this match (2 | 3 | 4).
  final int playerCount;

  /// The local user's assigned colour.
  final String myColor;

  /// Whose turn it is right now (colour name).
  final String currentTurn;

  /// Full list of players in seat order. When null, default mock players
  /// are used so the screen renders correctly in isolation.
  final List<GameUiPlayer>? players;

  /// Optional back callback for the top-left back button.
  final VoidCallback? onBack;

  @override
  State<FinalGameScreen> createState() => _FinalGameScreenState();
}

class _FinalGameScreenState extends State<FinalGameScreen> {
  // ── Emoji overlay state ────────────────────────────────────────────────────
  bool _showEmoji = false;

  // ── Preview toggle state (UI dev only — remove in production) ─────────────
  late int    _previewPlayerCount;
  late String _previewMyColor;
  late String _previewCurrentTurn;

  @override
  void initState() {
    super.initState();
    _previewPlayerCount  = widget.playerCount;
    _previewMyColor      = widget.myColor;
    _previewCurrentTurn  = widget.currentTurn;
  }

  // ── Default mock players ───────────────────────────────────────────────────

  static const List<GameUiPlayer> _defaultPlayers = [
    GameUiPlayer(
      name:        'Arjun Sharma',
      countryFlag: '🇮🇳',
      playerId:    '#A3F7',
      color:       'red',
    ),
    GameUiPlayer(
      name:        'Liam Chen',
      countryFlag: '🇨🇳',
      playerId:    '#B82C',
      color:       'blue',
    ),
    GameUiPlayer(
      name:        'Sofia Torres',
      countryFlag: '🇧🇷',
      playerId:    '#C1E9',
      color:       'yellow',
    ),
    GameUiPlayer(
      name:        'Kwame Asante',
      countryFlag: '🇬🇭',
      playerId:    '#D74A',
      color:       'green',
    ),
  ];

  List<GameUiPlayer> get _players => widget.players ?? _defaultPlayers;

  // ── Panel visibility per player count ─────────────────────────────────────
  //
  // Screen positions:
  //   TL = top-left     color: blue
  //   TR = top-right    color: yellow
  //   BL = bottom-left  color: red     (always YOU)
  //   BR = bottom-right color: green
  //
  // 2 players: BL + TR only
  // 3 players: BL + TL + TR
  // 4 players: all four

  bool get _showTL => _previewPlayerCount >= 3;
  bool get _showTR => _previewPlayerCount >= 2;
  bool get _showBR => _previewPlayerCount >= 4;

  // ── Player lookup by color ─────────────────────────────────────────────────

  GameUiPlayer _playerByColor(String color) {
    return _players.firstWhere(
      (p) => p.color == color,
      orElse: () => GameUiPlayer(
        name:        color.toUpperCase(),
        countryFlag: '🏳️',
        playerId:    '#0000',
        color:       color,
      ),
    );
  }

  PlayerPanelData _panelData(String color) {
    final p = _playerByColor(color);
    return PlayerPanelData(
      name:        p.name,
      countryFlag: p.countryFlag,
      playerId:    p.playerId,
      color:       color,
      avatarUrl:   p.avatarUrl,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Board fills 90% of screen width, capped at 370, min 220.
    final boardSize = (screenWidth * 0.90).clamp(220.0, 370.0);

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Main scrollable content ──────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top app bar ──────────────────────────────────────────────
                _TopBar(
                  playerCount: _previewPlayerCount,
                  myColor:     _previewMyColor,
                  onBack:      widget.onBack,
                  // Dev-only toggles
                  onToggleCount: () {
                    setState(() {
                      _previewPlayerCount =
                          _previewPlayerCount < 4 ? _previewPlayerCount + 1 : 2;
                    });
                  },
                  onCycleColor: () {
                    final colors = ['red', 'blue', 'yellow', 'green'];
                    final idx = colors.indexOf(_previewMyColor);
                    setState(() {
                      _previewMyColor      = colors[(idx + 1) % 4];
                      _previewCurrentTurn  = _previewMyColor;
                    });
                  },
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8,
                    ),
                    child: Column(
                      children: [
                        // ── Top player panels ──────────────────────────────
                        _TopPanelRow(
                          showTL:       _showTL,
                          showTR:       _showTR,
                          currentTurn:  _previewCurrentTurn,
                          myColor:      _previewMyColor,
                          panelDataTL:  _panelData('blue'),
                          panelDataTR:  _panelData('yellow'),
                          onEmoji:      () => setState(() => _showEmoji = true),
                        ),

                        const SizedBox(height: 10),

                        // ── Ludo Board ─────────────────────────────────────
                        _BoardArea(
                          boardSize:    boardSize,
                          myColor:      _previewMyColor,
                          playerCount:  _previewPlayerCount,
                        ),

                        const SizedBox(height: 14),

                        // ── Dice area ──────────────────────────────────────
                        _DiceArea(
                          isMyTurn: _previewCurrentTurn == _previewMyColor,
                        ),

                        const SizedBox(height: 14),

                        // ── Bottom player panels ───────────────────────────
                        _BottomPanelRow(
                          showBR:      _showBR,
                          currentTurn: _previewCurrentTurn,
                          myColor:     _previewMyColor,
                          panelDataBL: _panelData(_previewMyColor),
                          panelDataBR: _panelData('green'),
                          onEmoji:     () => setState(() => _showEmoji = true),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Emoji overlay ────────────────────────────────────────────────
          if (_showEmoji)
            _EmojiOverlay(
              onClose:     () => setState(() => _showEmoji = false),
              onEmojiSent: (_) => setState(() => _showEmoji = false),
            ),
        ],
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.playerCount,
    required this.myColor,
    required this.onBack,
    required this.onToggleCount,
    required this.onCycleColor,
  });

  final int           playerCount;
  final String        myColor;
  final VoidCallback? onBack;
  final VoidCallback  onToggleCount;
  final VoidCallback  onCycleColor;

  @override
  Widget build(BuildContext context) {
    final accent = _colorForName(myColor);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111128),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D4E))),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF9E9E9E),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),

          // Title
          const Expanded(
            child: Text(
              '1 MINUTE LUDO',
              style: TextStyle(
                color:         _kGold,
                fontSize:      15,
                fontWeight:    FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ),

          // ── Dev toggle: players ──────────────────────────────────────────
          _DevChip(
            label:    '$playerCount P',
            onTap:    onToggleCount,
          ),
          const SizedBox(width: 6),

          // ── Dev toggle: my color ─────────────────────────────────────────
          GestureDetector(
            onTap: onCycleColor,
            child: Container(
              width:  22,
              height: 22,
              decoration: BoxDecoration(
                color:  accent,
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevChip extends StatelessWidget {
  const _DevChip({required this.label, required this.onTap});

  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        const Color(0xFF2D2D4E),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: const Color(0xFF3D3D6E)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color:     Color(0xFF9E9E9E),
            fontSize:  10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── Board area ───────────────────────────────────────────────────────────────

class _BoardArea extends StatelessWidget {
  const _BoardArea({
    required this.boardSize,
    required this.myColor,
    required this.playerCount,
  });

  final double boardSize;
  final String myColor;
  final int    playerCount;

  List<String> get _activeColors => switch (playerCount) {
        2 => ['red', 'yellow'],
        3 => ['red', 'blue', 'yellow'],
        _ => ['red', 'blue', 'yellow', 'green'],
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color:       Colors.black.withAlpha(180),
              blurRadius:  24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: PremiumLudoBoardWidget(
          boardSize:    boardSize,
          activeColors: _activeColors,
          pawnCount:    4,
          rotation:     boardRotationForColor(myColor),
        ),
      ),
    );
  }
}

// ─── Top panel row ────────────────────────────────────────────────────────────

class _TopPanelRow extends StatelessWidget {
  const _TopPanelRow({
    required this.showTL,
    required this.showTR,
    required this.currentTurn,
    required this.myColor,
    required this.panelDataTL,
    required this.panelDataTR,
    required this.onEmoji,
  });

  final bool           showTL;
  final bool           showTR;
  final String         currentTurn;
  final String         myColor;
  final PlayerPanelData panelDataTL;
  final PlayerPanelData panelDataTR;
  final VoidCallback   onEmoji;

  @override
  Widget build(BuildContext context) {
    if (!showTL && !showTR) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TL panel (Blue) ─────────────────────────────────────────────────
        if (showTL)
          Expanded(
            child: PlayerPanelWidget(
              data:      panelDataTL,
              isMyPanel: panelDataTL.color == myColor,
              isActive:  currentTurn == panelDataTL.color,
              onEmoji:   onEmoji,
            ),
          ),

        if (showTL && showTR) const SizedBox(width: 8),

        // ── TR panel (Yellow) ───────────────────────────────────────────────
        if (showTR)
          Expanded(
            child: PlayerPanelWidget(
              data:      panelDataTR,
              isMyPanel: panelDataTR.color == myColor,
              isActive:  currentTurn == panelDataTR.color,
              onEmoji:   onEmoji,
            ),
          ),

        // ── Placeholder when only TR is shown (2-player) ────────────────────
        if (!showTL && showTR) const Expanded(child: SizedBox()),
      ],
    );
  }
}

// ─── Bottom panel row ─────────────────────────────────────────────────────────

class _BottomPanelRow extends StatelessWidget {
  const _BottomPanelRow({
    required this.showBR,
    required this.currentTurn,
    required this.myColor,
    required this.panelDataBL,
    required this.panelDataBR,
    required this.onEmoji,
  });

  final bool            showBR;
  final String          currentTurn;
  final String          myColor;
  final PlayerPanelData panelDataBL;
  final PlayerPanelData panelDataBR;
  final VoidCallback    onEmoji;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BL panel (always YOU / myColor) ───────────────────────────────
        Expanded(
          child: PlayerPanelWidget(
            data:      panelDataBL,
            isMyPanel: true,
            isActive:  currentTurn == panelDataBL.color,
            onEmoji:   onEmoji,
          ),
        ),

        if (showBR) const SizedBox(width: 8),

        // ── BR panel (Green) — only in 4-player ──────────────────────────
        if (showBR)
          Expanded(
            child: PlayerPanelWidget(
              data:      panelDataBR,
              isMyPanel: panelDataBR.color == myColor,
              isActive:  currentTurn == panelDataBR.color,
              onEmoji:   onEmoji,
            ),
          ),
      ],
    );
  }
}

// ─── Dice area ────────────────────────────────────────────────────────────────

/// Centred dice + "YOUR TURN" label below the board.
class _DiceArea extends StatelessWidget {
  const _DiceArea({required this.isMyTurn});

  final bool isMyTurn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Dice face
        _DiceFace(isMyTurn: isMyTurn),

        const SizedBox(height: 10),

        // Turn label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            isMyTurn ? 'YOUR TURN' : 'WAITING...',
            key: ValueKey(isMyTurn),
            style: TextStyle(
              color: isMyTurn
                  ? const Color(0xFFFFD700)
                  : const Color(0xFF616161),
              fontSize:      12,
              fontWeight:    FontWeight.bold,
              letterSpacing: 3.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiceFace extends StatefulWidget {
  const _DiceFace({required this.isMyTurn});

  final bool isMyTurn;

  @override
  State<_DiceFace> createState() => _DiceFaceState();
}

class _DiceFaceState extends State<_DiceFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        final pulse    = _glowAnim.value;
        final isMyTurn = widget.isMyTurn;
        final glowAlpha = isMyTurn
            ? (100 + pulse * 100).toInt()
            : 0;
        final borderColor = isMyTurn
            ? Color.lerp(
                const Color(0xFFFFD700),
                const Color(0xFFFFF176),
                pulse,
              )!
            : const Color(0xFF2D2D4E);
        final shadowBlur = isMyTurn ? 10.0 + pulse * 12.0 : 0.0;

        return Container(
          width:  72,
          height: 72,
          decoration: BoxDecoration(
            color:        const Color(0xFF111128),
            border:       Border.all(color: borderColor, width: 2.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (isMyTurn)
                BoxShadow(
                  color:      const Color(0xFFFFD700).withAlpha(glowAlpha),
                  blurRadius: shadowBlur,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: child,
        );
      },
      child: const Center(
        child: Text(
          '⚀',   // Unicode dice face (decorative placeholder)
          style: TextStyle(fontSize: 38),
        ),
      ),
    );
  }
}

// ─── Emoji overlay ────────────────────────────────────────────────────────────

const List<String> _kEmojis = [
  '😂', '😍', '🔥', '👏', '😎',
  '😤', '😱', '🤔', '💪', '🎉',
  '😭', '🙏', '🤣', '💀', '🤯',
  '😡', '🥳', '👍', '😅', '🏆',
];

class _EmojiOverlay extends StatelessWidget {
  const _EmojiOverlay({
    required this.onClose,
    required this.onEmojiSent,
  });

  final VoidCallback          onClose;
  final void Function(String) onEmojiSent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent close when tapping inside
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: const Color(0xFF2D2D4E)),
                boxShadow: [
                  BoxShadow(
                    color:       Colors.black.withAlpha(180),
                    blurRadius:  32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'QUICK EMOJI',
                        style: TextStyle(
                          color:         _kGold,
                          fontSize:      13,
                          fontWeight:    FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF616161),
                          size:  20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFF2D2D4E)),
                  const SizedBox(height: 8),

                  // Grid
                  GridView.builder(
                    shrinkWrap:  true,
                    physics:     const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:   5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing:  8,
                      childAspectRatio: 1,
                    ),
                    itemCount: _kEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = _kEmojis[index];
                      return GestureDetector(
                        onTap: () => onEmojiSent(emoji),
                        child: Container(
                          decoration: BoxDecoration(
                            color:        const Color(0xFF111128),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF2D2D4E),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
