import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ludo_path.dart';
import '../models/valid_move.dart';
import '../services/dice_service.dart';
import '../services/game_rules_service.dart';
import '../services/pawn_movement_service.dart';
import '../services/pawn_selection_service.dart';
import '../services/turn_manager.dart';
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

/// Lightweight player info for the final game UI.
class GameUiPlayer {
  const GameUiPlayer({
    required this.name,
    required this.countryFlag,
    required this.playerId,
    required this.color,
    this.avatarUrl,
    this.isBot = false,
  });

  final String  name;
  final String  countryFlag;
  final String  playerId;
  final String  color;      // 'red' | 'blue' | 'yellow' | 'green'
  final String? avatarUrl;

  /// `true` when this seat is a bot (auto-advances after 1 second).
  final bool isBot;
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
///   └──[BL panel]──[🎲 Dice]──[BR]──┘
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
    this.pawnCount   = 4,
    this.boardColor,
    this.players,
    this.onBack,
  });

  /// How many players are in this match (2 | 3 | 4).
  final int playerCount;

  /// The local user's assigned colour.
  final String myColor;

  /// Whose turn it is right now (colour name).
  final String currentTurn;

  /// Pawns per player (1 | 2 | 3 | 4).
  final int pawnCount;

  /// Board background colour theme ('red'|'yellow'|'green'|'blue'|null=classic).
  final String? boardColor;

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
  late int     _previewPlayerCount;
  late String  _previewMyColor;
  late int     _previewPawnCount;
  late String? _previewBoardColor;

  // ── Turn system ────────────────────────────────────────────────────────────
  TurnManager?              _turnManager;
  StreamSubscription<TurnState>? _turnSub;

  /// Driven entirely by [TurnManager]; never set manually.
  String _currentTurnColor = 'red';

  /// `true` only when the local player is the active player.
  bool _isDiceEnabled = false;

  /// Turn-timer progress from [TurnManager]: 1.0 = full, 0.0 = expired.
  /// Passed directly to every [PlayerPanelWidget] — single source of truth.
  double _timerProgress = 1.0;

  // ── Dice system ─────────────────────────────────────────────────────────────
  late DiceService _diceService;
  StreamSubscription<DiceState>? _diceSub;

  /// Latest dice state; drives [_DiceArea] via [_BottomPanelRow].
  DiceState _diceState = const DiceState(
    value:     null,
    isRolling: false,
    hasRolled: false,
  );

  // ── Pawn positions ───────────────────────────────────────────────────────────
  /// Absolute position for every pawn of every colour.
  /// 0 = yard (closed), 1–51 = track, 52–56 = home column, ≥57 = finished.
  Map<String, List<int>> _pawnPositions = {};

  // ── Pawn selection system ────────────────────────────────────────────────────
  late PawnSelectionService _pawnSelectionService;
  StreamSubscription<PawnSelectionState>? _pawnSelectionSub;

  /// Latest pawn selection state; drives the board overlay.
  PawnSelectionState _pawnSelectionState = const PawnSelectionState(
    validPawnIndices:  [],
    selectedPawnIndex: null,
  );

  // ── Pawn movement system ─────────────────────────────────────────────────────
  late PawnMovementService _pawnMovementService;

  /// True while a pawn animation is in progress; blocks new rolls and taps.
  bool _isMoving = false;

  // ── Game rules (Step 9) ───────────────────────────────────────────────────────
  late GameRulesService _gameRulesService;

  // ── Step 10: Home Entry + Winner Detection ────────────────────────────────────
  /// Ordered list of colors that have finished all pawns (1st place first).
  List<String> _rankingOrder = [];

  /// `true` once the game ends — no further turns are processed.
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _previewPlayerCount = widget.playerCount;
    _previewMyColor     = widget.myColor;
    _previewPawnCount   = widget.pawnCount;
    _previewBoardColor  = widget.boardColor;
    _diceService          = DiceService();
    _pawnSelectionService = PawnSelectionService();
    _pawnMovementService  = PawnMovementService();
    _gameRulesService     = GameRulesService();
    _pawnSelectionSub = _pawnSelectionService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _pawnSelectionState = state);
      // Trigger movement as soon as a pawn is selected (human or bot).
      if (state.selectedPawnIndex != null && !_pawnMovementService.isMoving) {
        _startMovement(state.selectedPawnIndex!);
      }
    });
    _initPawnPositions();
    _diceSub = _diceService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _diceState = state);
      // When rolling completes, compute valid pawns for the active player.
      if (state.hasRolled && state.value != null) {
        final positions = _pawnPositions[_currentTurnColor] ?? [];
        _pawnSelectionService.setValidPawns(
          diceValue: state.value!,
          positions: positions,
        );
        // Bots auto-select after a short delay to feel natural.
        // GameRulesService.selectBotPawn prefers cutting moves (extra turn).
        if (_botColors.contains(_currentTurnColor)) {
          final botColor  = _currentTurnColor;
          final diceVal   = state.value!;
          final positions = _pawnPositions[botColor] ?? [];
          final validMoves = _computeValidMoves(positions, diceVal);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            final idx = _gameRulesService.selectBotPawn(
              validMoves: validMoves,
              pawns:      _pawnPositions,
              botColor:   botColor,
            );
            if (idx != null) {
              _pawnSelectionService.selectPawn(idx);
            }
          });
        }
      }
    });
    _buildTurnManager();
  }

  @override
  void dispose() {
    _turnSub?.cancel();
    _turnManager?.dispose();
    _diceSub?.cancel();
    _diceService.dispose();
    _pawnSelectionSub?.cancel();
    _pawnSelectionService.dispose();
    _pawnMovementService.dispose();
    super.dispose();
  }

  // ── TurnManager lifecycle ──────────────────────────────────────────────────

  /// Returns the active colour set for the current preview player count.
  List<String> get _activeColors => switch (_previewPlayerCount) {
        2 => ['red', 'yellow'],
        3 => ['red', 'blue', 'yellow'],
        _ => ['red', 'blue', 'green', 'yellow'],
      };

  /// Colours that are bot-controlled (derived from the player list).
  Set<String> get _botColors => _players
      .where((p) => p.isBot)
      .map((p) => p.color)
      .toSet();

  /// (Re)creates [TurnManager] and subscribes to its state stream.
  ///
  /// Called on first mount and whenever a dev toggle changes the active
  /// player count or local colour.
  void _buildTurnManager() {
    _turnSub?.cancel();
    _turnManager?.dispose();
    _diceService.reset();
    _pawnSelectionService.reset();
    _pawnMovementService.cancel();
    _isMoving    = false;
    _rankingOrder = [];
    _gameOver     = false;
    _initPawnPositions();

    final tm = TurnManager(
      activeColors:      _activeColors,
      localPlayerColor:  _previewMyColor,
      botColors:         _botColors,
      initialTurn:       widget.currentTurn,
    );

    _turnSub = tm.stateStream.listen((state) {
      if (!mounted || _gameOver) return;
      final turnChanged = state.currentColor != _currentTurnColor;
      setState(() {
        _currentTurnColor = state.currentColor;
        _isDiceEnabled    = state.isDiceEnabled;
        _timerProgress    = state.timerProgress;
      });
      if (turnChanged) {
        _diceService.reset();
        _pawnSelectionService.reset();
        // Step 10: skip turns for players who have already finished.
        if (_rankingOrder.contains(state.currentColor)) {
          Future.microtask(() {
            if (mounted && !_gameOver) _turnManager?.advanceToNextTurn();
          });
          return;
        }
        if (_botColors.contains(state.currentColor)) {
          _diceService.scheduleBotRoll();
        }
      }
    });

    _turnManager      = tm;
    _currentTurnColor = tm.currentColor;
    _isDiceEnabled    = tm.isDiceEnabled;
    _timerProgress    = 1.0; // full at the start of every (re)build

    // Schedule bot roll if the very first turn belongs to a bot.
    if (_botColors.contains(tm.currentColor)) {
      _diceService.scheduleBotRoll();
    }
  }

  // ── Pawn movement ───────────────────────────────────────────────────────────

  /// Moves [pawnIndex] of the active colour by the current dice value,
  /// animating one tile at a time via [PawnMovementService].
  ///
  /// Triggered automatically from the pawn-selection stream for both human
  /// and bot players.  On completion, clears selection and resets dice.
  void _startMovement(int pawnIndex) {
    final diceValue = _diceService.currentDiceValue;
    if (diceValue == null) return;

    final color     = _currentTurnColor;
    final positions = _pawnPositions[color];
    if (positions == null || pawnIndex >= positions.length) return;

    final startPos = positions[pawnIndex];

    setState(() => _isMoving = true);

    _pawnMovementService.startMovement(
      startPosition: startPos,
      diceValue:     diceValue,
      onStep: (newPos) {
        if (!mounted) return;
        setState(() {
          final updated = List<int>.from(_pawnPositions[color]!);
          updated[pawnIndex] = newPos;
          _pawnPositions = Map<String, List<int>>.from(_pawnPositions)
            ..[color] = updated;
        });
      },
      onComplete: () {
        if (!mounted) return;

        // ── Step 9: Safe Cell + Cut Pawn + Extra Turn ───────────────────────
        // Read the final position that onStep settled on.
        final finalPos = _pawnPositions[color]?[pawnIndex] ?? startPos;

        // 2. Cut Pawn — detect whether the moved pawn landed on an opponent.
        final cut = _gameRulesService.findCut(
          pawns:       _pawnPositions,
          movingColor: color,
          toPos:       finalPos,
        );

        // 3. Extra Turn — dice == 6 OR a cut occurred.
        final extraTurn = _gameRulesService.getsExtraTurn(
          diceValue: diceValue,
          didCut:    cut != null,
        );

        setState(() {
          // Apply cut: reset captured pawn to yard with a new map reference
          // so Flutter detects the change and rebuilds the board overlay.
          if (cut != null) {
            final capturedList =
                List<int>.from(_pawnPositions[cut.capturedColor]!);
            capturedList[cut.capturedPawnIndex] = yardPosition;
            _pawnPositions = Map<String, List<int>>.from(_pawnPositions)
              ..[cut.capturedColor] = capturedList;
          }
          _isMoving = false;
        });

        _pawnSelectionService.reset();
        _diceService.reset();

        // ── Step 10: Home Entry + Winner Detection ────────────────────────────
        if (!_gameOver && finalPos >= homeFinished) {
          final allPositions = _pawnPositions[color] ?? [];
          final allFinished  = allPositions.every((p) => p >= homeFinished);
          if (allFinished && !_rankingOrder.contains(color)) {
            final newRanking = [..._rankingOrder, color];
            // If only 0 or 1 unranked player remains, auto-rank them and end.
            final remaining = _activeColors
                .where((c) => !newRanking.contains(c))
                .toList();
            if (remaining.length <= 1) {
              setState(() {
                _rankingOrder = List.unmodifiable([...newRanking, ...remaining]);
                _gameOver     = true;
              });
              _endGame();
              return; // game over — no extra turn or advance.
            }
            setState(() => _rankingOrder = List.unmodifiable(newRanking));
          }
        }

        if (_gameOver) return;

        if (extraTurn) {
          // Same player gets another roll — reset timer without advancing.
          _turnManager?.grantExtraTurn();
          // Bots immediately schedule their next roll.
          if (_botColors.contains(color)) {
            _diceService.scheduleBotRoll();
          }
        } else {
          // Pass turn to the next player.
          _turnManager?.advanceToNextTurn();
        }
      },
    );
  }

  // ── End-game teardown ────────────────────────────────────────────────────────

  /// Stops the turn clock and releases [TurnManager] resources.
  ///
  /// Called once [_gameOver] is set to `true`.  Safe to call multiple times.
  void _endGame() {
    _turnSub?.cancel();
    _turnSub = null;
    _turnManager?.dispose();
    _turnManager = null;
  }

  // ── Valid-move builder (Step 9 — used for bot pawn selection) ────────────────

  /// Build [ValidMove] objects from a player's pawn [positions] and [diceValue].
  ///
  /// Mirrors the server-side `computeValidMoves` logic in `game_engine.ts` and
  /// the [PawnSelectionService.computeValid] helper, but returns full
  /// [ValidMove] objects (with [toPos]) needed by [GameRulesService.selectBotPawn].
  List<ValidMove> _computeValidMoves(List<int> positions, int diceValue) {
    final moves = <ValidMove>[];
    for (var i = 0; i < positions.length; i++) {
      final pos = positions[i];
      if (pos >= homeFinished) continue; // already finished
      if (pos == yardPosition) {
        if (diceValue == 6) {
          moves.add(ValidMove(
            pawnIndex: i,
            fromPos:   yardPosition,
            toPos:     trackEntryPosition,
          ));
        }
      } else {
        final toPos = pos + diceValue;
        if (toPos <= homeFinished) {
          moves.add(ValidMove(pawnIndex: i, fromPos: pos, toPos: toPos));
        }
      }
    }
    return moves;
  }

  /// Initialise (or reset) pawn positions to all-zero (all pawns in yard).
  ///
  /// Called at game start and whenever [_buildTurnManager] restarts the session.
  void _initPawnPositions() {
    _pawnPositions = {
      for (final color in ['red', 'blue', 'yellow', 'green'])
        color: List.filled(_previewPawnCount, 0),
    };
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
                  // Dev-only toggles — each rebuilds TurnManager so the
                  // turn system restarts with the new configuration.
                  onToggleCount: () {
                    setState(() {
                      _previewPlayerCount =
                          _previewPlayerCount < 4 ? _previewPlayerCount + 1 : 2;
                    });
                    _buildTurnManager();
                  },
                  onCycleColor: () {
                    final colors = ['red', 'blue', 'yellow', 'green'];
                    final idx    = colors.indexOf(_previewMyColor);
                    setState(() {
                      _previewMyColor = colors[(idx + 1) % 4];
                    });
                    _buildTurnManager();
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
                          showTL:        _showTL,
                          showTR:        _showTR,
                          currentTurn:   _currentTurnColor,
                          myColor:       _previewMyColor,
                          timerProgress: _timerProgress,
                          panelDataTL:   _panelData('blue'),
                          panelDataTR:   _panelData('yellow'),
                          onEmoji:       () => setState(() => _showEmoji = true),
                        ),

                        const SizedBox(height: 10),

                        // ── Ludo Board ─────────────────────────────────────
                        _BoardArea(
                          boardSize:         boardSize,
                          myColor:           _previewMyColor,
                          playerCount:       _previewPlayerCount,
                          pawnCount:         _previewPawnCount,
                          boardThemeColor:   _previewBoardColor,
                          pawnPositions:     _pawnPositions,
                          activeColor:       _currentTurnColor,
                          validPawnIndices:  _pawnSelectionState.validPawnIndices,
                          selectedPawnIndex: _pawnSelectionState.selectedPawnIndex,
                          isMyTurn: _isDiceEnabled && _diceState.hasRolled && !_isMoving,
                          onSelectPawn:      _pawnSelectionService.selectPawn,
                        ),

                        const SizedBox(height: 14),

                        // ── Bottom player panels with dice between them ────
                        _BottomPanelRow(
                          showBR:        _showBR,
                          currentTurn:   _currentTurnColor,
                          myColor:       _previewMyColor,
                          isMyTurn:      _isDiceEnabled,
                          timerProgress: _timerProgress,
                          panelDataBL:   _panelData(_previewMyColor),
                          panelDataBR:   _panelData('green'),
                          onEmoji:       () => setState(() => _showEmoji = true),
                          diceValue:     _diceState.value,
                          isRolling:     _diceState.isRolling,
                          canRoll:       _diceState.canRoll && _isDiceEnabled,
                          onRoll:        _diceService.roll,
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
    required this.pawnCount,
    this.boardThemeColor,
    required this.pawnPositions,
    required this.activeColor,
    required this.validPawnIndices,
    this.selectedPawnIndex,
    required this.isMyTurn,
    required this.onSelectPawn,
  });

  final double                 boardSize;
  final String                 myColor;
  final int                    playerCount;
  final int                    pawnCount;
  final String?                boardThemeColor;
  final Map<String, List<int>> pawnPositions;
  final String                 activeColor;
  final List<int>              validPawnIndices;
  final int?                   selectedPawnIndex;
  final bool                   isMyTurn;
  final void Function(int)     onSelectPawn;

  List<String> get _activeColors => switch (playerCount) {
        2 => ['red', 'yellow'],
        3 => ['red', 'blue', 'yellow'],
        _ => ['red', 'blue', 'yellow', 'green'],
      };

  @override
  Widget build(BuildContext context) {
    final rotation = boardRotationForColor(myColor);
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Board (applies rotation internally)
            PremiumLudoBoardWidget(
              boardSize:       boardSize,
              activeColors:    _activeColors,
              pawnCount:       pawnCount,
              rotation:        rotation,
              boardThemeColor: boardThemeColor,
            ),
            // Pawn selection overlay (same rotation as board content)
            Transform.rotate(
              angle: rotation,
              child: _PawnSelectionOverlay(
                boardSize:         boardSize,
                pawnCount:         pawnCount,
                activeColor:       activeColor,
                pawnPositions:     pawnPositions,
                validPawnIndices:  validPawnIndices,
                selectedPawnIndex: selectedPawnIndex,
                isMyTurn:          isMyTurn,
                onSelectPawn:      onSelectPawn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pawn selection overlay ───────────────────────────────────────────────────

/// Transparent overlay that draws highlight rings over selectable pawns and
/// forwards taps to [onSelectPawn].
///
/// The overlay is rendered in the same rotated coordinate space as the board
/// (caller applies the matching [Transform.rotate] before placing this widget).
/// Only the active player's pawns are highlighted; other colours are ignored.
class _PawnSelectionOverlay extends StatefulWidget {
  const _PawnSelectionOverlay({
    required this.boardSize,
    required this.pawnCount,
    required this.activeColor,
    required this.pawnPositions,
    required this.validPawnIndices,
    this.selectedPawnIndex,
    required this.isMyTurn,
    required this.onSelectPawn,
  });

  final double                 boardSize;
  final int                    pawnCount;
  final String                 activeColor;
  final Map<String, List<int>> pawnPositions;
  final List<int>              validPawnIndices;
  final int?                   selectedPawnIndex;
  final bool                   isMyTurn;
  final void Function(int)     onSelectPawn;

  @override
  State<_PawnSelectionOverlay> createState() => _PawnSelectionOverlayState();
}

class _PawnSelectionOverlayState extends State<_PawnSelectionOverlay>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Position helpers (mirror the board painter's maths) ───────────────────

  static (int, int) _yardStart(String color) => switch (color) {
        'red'    => (9, 0),
        'blue'   => (0, 0),
        'yellow' => (0, 9),
        'green'  => (9, 9),
        _        => (9, 0),
      };

  static int _colorEntryAbs(String color) => switch (color) {
        'red'    => 0,
        'blue'   => 15,
        'green'  => 28,
        'yellow' => 41,
        _        => 0,
      };

  static List<Offset> _yardSpots(
      int pawnCount, int startRow, int startCol, double cs) {
    return switch (pawnCount) {
      1 => [Offset((startCol + 2.5) * cs, (startRow + 2.5) * cs)],
      2 => [
          Offset((startCol + 1.5) * cs, (startRow + 2.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 2.5) * cs),
        ],
      3 => [
          Offset((startCol + 2.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 1.5) * cs, (startRow + 3.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 3.5) * cs),
        ],
      _ => [
          Offset((startCol + 1.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 1.5) * cs),
          Offset((startCol + 1.5) * cs, (startRow + 3.5) * cs),
          Offset((startCol + 3.5) * cs, (startRow + 3.5) * cs),
        ],
    };
  }

  /// Screen-space offset for [color]'s pawn [pawnIndex] at [position].
  Offset _pawnOffset(String color, int pawnIndex, int position) {
    final cs = widget.boardSize / 15;

    if (position == 0) {
      // Yard (closed)
      final (startRow, startCol) = _yardStart(color);
      final spots = _yardSpots(widget.pawnCount, startRow, startCol, cs);
      if (pawnIndex < spots.length) return spots[pawnIndex];
      return Offset.zero;
    } else if (position >= 1 && position <= 51) {
      // Main track
      final entryAbs = _colorEntryAbs(color);
      final absIdx   = (entryAbs + position - 1) % kPremiumTrackCells.length;
      final (row, col) = kPremiumTrackCells[absIdx];
      return Offset((col + 0.5) * cs, (row + 0.5) * cs);
    } else if (position >= 52 && position <= 56) {
      // Home column
      final cells    = kPremiumHomeCells[color];
      final cellIdx  = position - 52;
      if (cells != null && cellIdx < cells.length) {
        final (row, col) = cells[cellIdx];
        return Offset((col + 0.5) * cs, (row + 0.5) * cs);
      }
      return Offset.zero;
    } else {
      // Finished — centre of board
      return Offset(widget.boardSize / 2, widget.boardSize / 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs       = widget.boardSize / 15;
    final pawnR    = cs * 0.40;   // matches board painter pawn radius
    final hitR     = pawnR * 1.6; // slightly larger tap target

    final positions = widget.pawnPositions[widget.activeColor] ?? [];

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final pulse = _pulseAnim.value;
        final items = <Widget>[];

        for (var i = 0; i < positions.length; i++) {
          final isValid    = widget.validPawnIndices.contains(i);
          final isSelected = widget.selectedPawnIndex == i;

          if (!isValid && !isSelected) continue;

          final offset  = _pawnOffset(widget.activeColor, i, positions[i]);
          final hitSize = hitR * 2;

          items.add(
            Positioned(
              left:   offset.dx - hitR,
              top:    offset.dy - hitR,
              width:  hitSize,
              height: hitSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (isValid && widget.isMyTurn)
                    ? () => widget.onSelectPawn(i)
                    : null,
                child: CustomPaint(
                  painter: _RingPainter(
                    pawnRadius: pawnR,
                    pulse:      pulse,
                    isSelected: isSelected,
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width:  widget.boardSize,
          height: widget.boardSize,
          child: Stack(children: items),
        );
      },
    );
  }
}

// ─── Ring painter ─────────────────────────────────────────────────────────────

/// Draws a pulsing highlight ring (+ optional selection fill) over a pawn.
///
/// The widget is sized to `pawnRadius * 1.6 * 2` square — the painter centres
/// the ring at the widget's midpoint.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.pawnRadius,
    required this.pulse,
    required this.isSelected,
  });

  static const Color _kGold = Color(0xFFFFD700);

  final double pawnRadius;
  final double pulse;
  final bool   isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final r      = pawnRadius;

    if (isSelected) {
      // Solid glow fill for selected pawn
      canvas.drawCircle(
        centre, r,
        Paint()
          ..color      = _kGold.withAlpha((80 + pulse * 60).toInt())
          ..style      = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Thick ring
      canvas.drawCircle(
        centre, r,
        Paint()
          ..color       = _kGold
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    } else {
      // Pulsing outer glow
      canvas.drawCircle(
        centre, r,
        Paint()
          ..color      = _kGold.withAlpha((60 + pulse * 100).toInt())
          ..style      = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(
              BlurStyle.normal, 4.0 + pulse * 8.0),
      );
      // Pulsing ring
      canvas.drawCircle(
        centre, r,
        Paint()
          ..color       = _kGold.withAlpha((160 + pulse * 95).toInt())
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5 + pulse * 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pulse      != pulse      ||
      old.isSelected != isSelected ||
      old.pawnRadius != pawnRadius;
}

// ─── Top panel row ────────────────────────────────────────────────────────────

class _TopPanelRow extends StatelessWidget {
  const _TopPanelRow({
    required this.showTL,
    required this.showTR,
    required this.currentTurn,
    required this.myColor,
    required this.timerProgress,
    required this.panelDataTL,
    required this.panelDataTR,
    required this.onEmoji,
  });

  final bool            showTL;
  final bool            showTR;
  final String          currentTurn;
  final String          myColor;
  final double          timerProgress;
  final PlayerPanelData panelDataTL;
  final PlayerPanelData panelDataTR;
  final VoidCallback    onEmoji;

  @override
  Widget build(BuildContext context) {
    if (!showTL && !showTR) return const SizedBox.shrink();

    // Only the active panel gets the live countdown; inactive panels show full.
    final tlProgress = currentTurn == panelDataTL.color ? timerProgress : 1.0;
    final trProgress = currentTurn == panelDataTR.color ? timerProgress : 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TL panel (Blue) ─────────────────────────────────────────────────
        if (showTL)
          Expanded(
            child: PlayerPanelWidget(
              data:          panelDataTL,
              isMyPanel:     panelDataTL.color == myColor,
              isActive:      currentTurn == panelDataTL.color,
              timerProgress: tlProgress,
              onEmoji:       onEmoji,
            ),
          ),

        if (showTL && showTR) const SizedBox(width: 8),

        // ── TR panel (Yellow) ───────────────────────────────────────────────
        if (showTR)
          Expanded(
            child: PlayerPanelWidget(
              data:          panelDataTR,
              isMyPanel:     panelDataTR.color == myColor,
              isActive:      currentTurn == panelDataTR.color,
              timerProgress: trProgress,
              onEmoji:       onEmoji,
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
    required this.isMyTurn,
    required this.timerProgress,
    required this.panelDataBL,
    required this.panelDataBR,
    required this.onEmoji,
    required this.diceValue,
    required this.isRolling,
    required this.canRoll,
    required this.onRoll,
  });

  final bool            showBR;
  final String          currentTurn;
  final String          myColor;
  final bool            isMyTurn;
  final double          timerProgress;
  final PlayerPanelData panelDataBL;
  final PlayerPanelData panelDataBR;
  final VoidCallback    onEmoji;
  final int?            diceValue;
  final bool            isRolling;
  final bool            canRoll;
  final VoidCallback    onRoll;

  @override
  Widget build(BuildContext context) {
    // Only the active panel gets the live countdown; inactive panels show full.
    final blProgress = currentTurn == panelDataBL.color ? timerProgress : 1.0;
    final brProgress = currentTurn == panelDataBR.color ? timerProgress : 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── BL panel (always YOU / myColor) ───────────────────────────────
        Expanded(
          child: PlayerPanelWidget(
            data:          panelDataBL,
            isMyPanel:     true,
            isActive:      currentTurn == panelDataBL.color,
            timerProgress: blProgress,
            onEmoji:       onEmoji,
          ),
        ),

        // ── Dice centred between the two bottom panels ─────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _DiceArea(
            isMyTurn:  isMyTurn,
            diceValue: diceValue,
            isRolling: isRolling,
            canRoll:   canRoll,
            onRoll:    onRoll,
          ),
        ),

        // ── BR panel (Green) — only in 4-player; spacer otherwise ─────────
        Expanded(
          child: showBR
              ? PlayerPanelWidget(
                  data:          panelDataBR,
                  isMyPanel:     panelDataBR.color == myColor,
                  isActive:      currentTurn == panelDataBR.color,
                  timerProgress: brProgress,
                  onEmoji:       onEmoji,
                )
              : const SizedBox(),
        ),
      ],
    );
  }
}

// ─── Dice area ────────────────────────────────────────────────────────────────

/// Centred dice face + status label between the two bottom player panels.
///
/// Passes all dice state down to [_DiceFace]; this widget itself is stateless.
class _DiceArea extends StatelessWidget {
  const _DiceArea({
    required this.isMyTurn,
    required this.diceValue,
    required this.isRolling,
    required this.canRoll,
    required this.onRoll,
  });

  final bool         isMyTurn;
  final int?         diceValue;
  final bool         isRolling;
  final bool         canRoll;
  final VoidCallback onRoll;

  String get _label {
    if (isRolling)          return 'ROLLING…';
    if (diceValue != null)  return 'ROLLED $diceValue';
    if (isMyTurn)           return 'YOUR TURN';
    return 'WAITING…';
  }

  Color get _labelColor {
    if (isRolling)         return const Color(0xFF6C63FF);
    if (diceValue != null) return const Color(0xFFFFD700);
    if (isMyTurn)          return const Color(0xFFFFD700);
    return const Color(0xFF616161);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DiceFace(
          isMyTurn:  isMyTurn,
          diceValue: diceValue,
          isRolling: isRolling,
          onTap:     canRoll ? onRoll : null,
        ),

        const SizedBox(height: 10),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _label,
            key: ValueKey(_label),
            style: TextStyle(
              color:         _labelColor,
              fontSize:      11,
              fontWeight:    FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dice face ────────────────────────────────────────────────────────────────

/// Animated dice face widget.
///
/// Behaviour:
///  - **Idle (no roll yet, my turn):** gold pulsing glow, shows ⚀ placeholder,
///    tappable via [onTap].
///  - **Rolling:** cycles through all six Unicode die faces every 80 ms to
///    simulate a tumbling animation; purple border pulses.
///  - **Rolled:** shows the final [diceValue] die face; gold border, not tappable.
///  - **Waiting (not my turn):** dim border, ⚀ placeholder, not tappable.
class _DiceFace extends StatefulWidget {
  const _DiceFace({
    required this.isMyTurn,
    required this.diceValue,
    required this.isRolling,
    required this.onTap,
  });

  final bool         isMyTurn;
  final int?         diceValue;
  final bool         isRolling;
  final VoidCallback? onTap;

  @override
  State<_DiceFace> createState() => _DiceFaceState();
}

class _DiceFaceState extends State<_DiceFace>
    with SingleTickerProviderStateMixin {

  // Pulsing glow controller (runs continuously).
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  // Cycling display value shown during the rolling animation.
  int    _cycleValue = 1;
  Timer? _cycleTimer;

  // Pseudo-random generator for the cycling animation.
  final math.Random _rng = math.Random();

  // Unicode die faces: ⚀ ⚁ ⚂ ⚃ ⚄ ⚅
  static String _dieFace(int value) =>
      String.fromCharCode(0x2680 + value - 1);

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    if (widget.isRolling) _startCycling();
  }

  @override
  void didUpdateWidget(_DiceFace old) {
    super.didUpdateWidget(old);
    if (widget.isRolling && !old.isRolling) {
      _startCycling();
    } else if (!widget.isRolling && old.isRolling) {
      _stopCycling();
    }
  }

  @override
  void dispose() {
    _stopCycling();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _startCycling() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() => _cycleValue = _rng.nextInt(6) + 1);
    });
  }

  void _stopCycling() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        final pulse     = _glowAnim.value;
        final rolling   = widget.isRolling;
        final rolled    = widget.diceValue != null && !rolling;
        final myTurn    = widget.isMyTurn;

        final glowAlpha = rolling
            ? (80 + pulse * 120).toInt()
            : (myTurn && !rolled)
                ? (60 + pulse * 100).toInt()
                : 0;

        final borderColor = rolling
            ? Color.lerp(
                const Color(0xFF6C63FF),
                const Color(0xFFA89AFF),
                pulse,
              )!
            : rolled
                ? Color.lerp(
                    const Color(0xFFFFD700),
                    const Color(0xFFFFF176),
                    pulse,
                  )!
                : myTurn
                    ? Color.lerp(
                        const Color(0xFFFFD700),
                        const Color(0xFFFFF176),
                        pulse,
                      )!
                    : const Color(0xFF2D2D4E);

        final shadowColor = rolling
            ? const Color(0xFF6C63FF)
            : const Color(0xFFFFD700);

        final shadowBlur = (rolling || (myTurn && !rolled))
            ? 10.0 + pulse * 14.0
            : 0.0;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width:  72,
            height: 72,
            decoration: BoxDecoration(
              color:        const Color(0xFF111128),
              border:       Border.all(color: borderColor, width: 2.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (shadowBlur > 0)
                  BoxShadow(
                    color:       shadowColor.withAlpha(glowAlpha),
                    blurRadius:  shadowBlur,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 60),
          child: Text(
            widget.isRolling
                ? _dieFace(_cycleValue)
                : widget.diceValue != null
                    ? _dieFace(widget.diceValue!)
                    : '⚀',
            key: ValueKey(
              widget.isRolling
                  ? 'r$_cycleValue'
                  : 'd${widget.diceValue}',
            ),
            style: TextStyle(
              fontSize: 38,
              color: widget.diceValue != null && !widget.isRolling
                  ? const Color(0xFFFFD700)
                  : null,
            ),
          ),
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
