import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_minute_ludo/features/game/screens/game_screen.dart';
import 'package:one_minute_ludo/features/matchmaking/models/game_started.dart';
import 'package:one_minute_ludo/features/matchmaking/models/match_found.dart';
import 'package:one_minute_ludo/features/matchmaking/models/opponent.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kMatchFound = MatchFound(
  matchId:  'match-uuid-1',
  roomCode: 'ABC123',
  color:    'blue',
  opponent: Opponent(
    playerId: 'LUD-OPP001',
    fullName: 'Opponent Player',
  ),
);

const _kGameStarted = GameStarted(
  matchId:   'match-uuid-1',
  firstTurn: 'red',
);

Future<void> _pump(
  WidgetTester tester, {
  GameStarted?  gameStarted,
  MatchFound?   matchFound,
  VoidCallback? onForfeit,
  VoidCallback? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        gameStarted:      gameStarted      ?? _kGameStarted,
        matchFound:       matchFound       ?? _kMatchFound,
        onForfeit:        onForfeit        ?? () {},
        onSessionExpired: onSessionExpired ?? () {},
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Smoke ──────────────────────────────────────────────────────────────────

  testWidgets('1 — smoke: renders without crashing', (tester) async {
    await _pump(tester);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  // ── AppBar ─────────────────────────────────────────────────────────────────

  testWidgets('2 — AppBar is present with game_screen_app_bar key', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('game_screen_app_bar')), findsOneWidget);
  });

  testWidgets('3 — AppBar title shows "Game"', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('game_screen_app_bar')),
        matching: find.text('Game'),
      ),
      findsOneWidget,
    );
  });

  // ── First turn banner ──────────────────────────────────────────────────────

  testWidgets('4 — first_turn_banner widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('first_turn_banner')), findsOneWidget);
  });

  testWidgets('5 — first turn banner shows correct colour (RED first turn)',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('first_turn_text')), findsOneWidget);
    // opponent goes first (red ≠ my color blue)
    expect(find.textContaining('RED'), findsOneWidget);
  });

  testWidgets('6 — first turn banner says "You go first" when it is my turn',
      (tester) async {
    await _pump(
      tester,
      gameStarted: const GameStarted(matchId: 'match-uuid-1', firstTurn: 'blue'),
      matchFound:  _kMatchFound, // my color is blue
    );
    expect(find.textContaining('You go first'), findsOneWidget);
  });

  testWidgets('7 — first turn banner says "Opponent goes first" when it is not my turn',
      (tester) async {
    // my color is blue, firstTurn is red → opponent goes first
    await _pump(tester);
    expect(find.textContaining('Opponent goes first'), findsOneWidget);
  });

  // ── Match information card ─────────────────────────────────────────────────

  testWidgets('8 — match_info_card widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('match_info_card')), findsOneWidget);
  });

  testWidgets('9 — opponent name is shown in match info card', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('opponent_name')), findsOneWidget);
    expect(find.text('Opponent Player'), findsOneWidget);
  });

  testWidgets('10 — my colour chip is shown', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('my_color_chip')), findsOneWidget);
    expect(find.text('BLUE'), findsOneWidget);
  });

  testWidgets('11 — room code is shown', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('room_code')), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  // ── Placeholder board ──────────────────────────────────────────────────────

  testWidgets('12 — placeholder_board widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('placeholder_board')), findsOneWidget);
  });

  testWidgets('13 — placeholder board shows "Board coming in Phase 6" text',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('placeholder_board_text')), findsOneWidget);
    expect(find.textContaining('Phase 6'), findsOneWidget);
  });

  // ── Forfeit button ─────────────────────────────────────────────────────────

  testWidgets('14 — forfeit_button widget is present', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('forfeit_button')), findsOneWidget);
  });

  testWidgets('15 — tapping forfeit button fires onForfeit callback', (tester) async {
    var forfeitCalled = false;
    await _pump(tester, onForfeit: () => forfeitCalled = true);

    await tester.tap(find.byKey(const Key('forfeit_button')));
    await tester.pump();

    expect(forfeitCalled, isTrue);
  });
}
