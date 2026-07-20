# 09_CHANGELOG.md

# CHANGELOG

All significant changes to this project must be recorded here.

------------------------------------------------------------------------

## Versioning

Format:

-   Version
-   Date
-   Author (AI or Developer)
-   Summary
-   Details

------------------------------------------------------------------------

## v0.20.0

### Date

2026-07-20

### Author

Replit Agent

### Summary

Phase 6.4C complete — Flutter: LudoBoardWidget pawn rendering (yard,
track, home column, finished positions; stacking offsets; 8 new tests).

### Details

**Flutter — modified files**

-   `mobile/lib/features/game/widgets/ludo_board_widget.dart`:
    -   `LudoBoardWidget` — new optional `pawns: Map<String, List<int>>?`
        parameter; when `null` the widget behaves identically to Phase
        6.4B (fully backward compatible)
    -   `_LudoBoardPainter` — new `pawns` field; paint order extended with
        `_drawPawns(canvas)` called after grid lines so pawns appear on
        top; `shouldRepaint` updated to include `pawns` comparison
    -   `_drawPawns` — three-step rendering:
        1. **Yard pawns**: each pawn index (0–3) mapped to its fixed
           placeholder circle (top-left, top-right, bottom-left,
           bottom-right); radius `cs × 0.38` matching placeholder size
        2. **Track / home-column pawns**: collected into a `Map<(row,col),
           List<(colour, index)>>`; groups drawn with `_stackOffset`
           so multiple pawns on the same cell remain individually visible
           (1 pawn: centred; 2: left/right; 3: triangle; 4: 2×2 grid);
           radius `cs × 0.30`
        3. **Finished pawns** (position 57): drawn at each colour's
           triangle centroid in the 3×3 centre area (Red→left, Blue→top,
           Green→right, Yellow→bottom); radius `cs × 0.24`; same stacking
           layout
    -   New helpers: `_kYardStart` (static const), `_pawnColor`,
        `_yardSpotCenter`, `_finishedCenter`, `_stackOffset` (static),
        `_drawPawnCircle`

-   `mobile/test/features/game/widgets/ludo_board_widget_test.dart`:
    -   New group `LudoBoardWidget — pawns` — 8 tests (28–35):
        null pawns backward compat, all in yard, pawns on track, home
        column positions, finished (position 57), mixed positions,
        multiple pawns on the same cell (stacking), custom boardSize
        with pawns; all use `pumpAndSettle` + `takeException() isNull`

**No backend changes** — Phase 6.4C is Flutter only.

**No new packages** — no changes to `pubspec.yaml`.

**No GameScreen / MainShell / GameService changes** — pawn interaction
and tap callbacks deferred to Phase 6.5.

**Design decisions**

-   `pawns` parameter is optional (`null` default) so all existing callers
    of `LudoBoardWidget` compile unchanged — zero regressions.
-   Yard spots use pixel offsets identical to `_drawOneYard` placeholder
    circles, so real pawns precisely replace the placeholders.
-   Stacking offsets use `cs × 0.55` step, keeping all pawns within
    their cell boundary at the default 360 px board size.
-   Finished centroids are the geometric centroids of each coloured
    triangle: Red (6.5, 7.5), Blue (7.5, 6.5), Green (8.5, 7.5),
    Yellow (7.5, 8.5) in (col, row) cell units.

------------------------------------------------------------------------

## v0.19.0

### Date

2026-07-20

### Author

Replit Agent

### Summary

Phase 6.4B complete — Flutter: LudoBoardWidget static 15 × 15 Ludo board
(grid, home yards, home paths, safe-square markers).

### Details

**Flutter — new files**
-   `mobile/lib/features/game/widgets/ludo_board_widget.dart`:
    -   `LudoBoardWidget` — `StatelessWidget` wrapping a `CustomPaint`;
        accepts optional `boardSize` (default 360 logical pixels)
    -   `kTrackCells` — `List<(int, int)>`, 52 absolute track positions
        mapped to (row, col) on the 15 × 15 grid; clockwise from Red entry
    -   `kHomeCells` — `Map<String, List<(int, int)>>`, 5-cell home column
        per colour (relPos 52–56) in the middle row/col of each arm
    -   `_LudoBoardPainter extends CustomPainter` — draws in paint order:
        1. White background
        2. Four coloured 6 × 6 corner yards (outer fill + inner white rounded
           rect + 4 pawn-placeholder circles)
        3. Coloured home paths (light tint, 5 cells per colour)
        4. Centre 3 × 3 finishing area (4 coloured triangles + white star)
        5. Safe-square star markers on all 8 [safeAbsolutePositions]
        6. 15 × 15 grid lines
        7. Outer board border

-   `mobile/test/features/game/widgets/ludo_board_widget_test.dart` — 27 tests:
    -   Widget tests (1–9): smoke, default size (360 × 360), custom size,
        square constraint, CustomPaint present, key forwarded, small/large
        sizes, no layout overflow
    -   kTrackCells data tests (10–19): 52 entries, no duplicates, all in
        grid, each cell adjacent to next (path continuity), all four entry
        squares match [colorEntryOffset], all 8 safe indices valid, star
        squares are 8 steps from each entry
    -   kHomeCells data tests (20–27): four colours present, 5 cells each,
        no overlap with main track, all in grid, track→home adjacency for
        all four colours

**No backend changes** — Phase 6.4B is Flutter only.

**No new packages** — no changes to `pubspec.yaml`.

**No GameScreen / MainShell / GameService changes** — static board only.

**Design decisions**
-   Track runs clockwise: up col 1 → right row 0 → down col 13 →
    left row 14, giving entry offsets Red=0, Blue=13, Green=26, Yellow=39
    that match [colorEntryOffset] exactly.
-   Home column entry cells are adjacent (distance 1) to the last track
    cell of each colour: abs 51→(7,2) Red, abs 12→(1,7) Blue,
    abs 25→(7,12) Green, abs 38→(13,7) Yellow.
-   Centre finishing area uses four triangles meeting at pixel (7.5×cs,
    7.5×cs) so the visual direction of each triangle matches the approach
    direction of the corresponding colour.
-   flutter analyze and flutter test deferred to local/CI environment
    (Flutter SDK not installed in Replit). ⚠️

------------------------------------------------------------------------

## v0.18.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 6.4A complete — Flutter: LudoPath board/path coordinate constants
(`ludo_path.dart`); mirrors `game_engine.ts` exactly; no widget rendering.

### Details

**Flutter — new files**
-   `mobile/lib/features/game/models/ludo_path.dart`:
    -   `trackLength = 52` — total shared-track cells (mirrors `TRACK_LENGTH`)
    -   `yardPosition = 0` — pawn not yet on board
    -   `trackEntryPosition = 1` — first position on the shared track
    -   `homeColumnStart = 52`, `homeColumnEnd = 56` — colour-specific column
    -   `homeFinished = 57` — winning position (mirrors `HOME_FINISHED`)
    -   `colorEntryOffset` map — red→0, blue→13, green→26, yellow→39
        (mirrors `COLOR_ENTRY_OFFSET`)
    -   `safeAbsolutePositions` set — {0, 8, 13, 21, 26, 34, 39, 47}
        (mirrors `SAFE_ABSOLUTE_POSITIONS`); entry squares + star squares
    -   `relativeToAbsolute(relPos, color)` — colour-relative → absolute
        track position; mirrors backend utility
    -   `isAbsoluteSafe(absPos)` — checks safe-square set; mirrors backend
        utility

**No backend changes** — Phase 6.4A is Flutter only.

**No new packages** — no changes to `pubspec.yaml`.

**No widget rendering** — no LudoBoardWidget, no GameScreen changes,
no MainShell changes, no GameService changes.

------------------------------------------------------------------------

## v0.17.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 6.3 complete — Flutter: Models + GameService (DiceRolled, PawnMoved,
TurnChanged, ValidMove models; GameService with rollDice / movePawn / streams;
73 new unit tests; flutter analyze clean)

### Details

**Flutter — new files**
-   `mobile/lib/features/game/models/valid_move.dart`:
    -   `ValidMove(pawnIndex, fromPos, toPos)` — typed model for a single
        legal pawn move entry inside `DiceRolled.validMoves`
    -   `fromJson(Map<String, dynamic>)` — validates all three fields are
        integers; throws `FormatException` otherwise
    -   `==`, `hashCode`, `toString`
-   `mobile/lib/features/game/models/dice_rolled.dart`:
    -   `DiceRolled(matchId, color, value, validMoves)` — payload of the
        `dice_rolled` Socket.IO event (Phase 6.1)
    -   `fromJson` — validates matchId (String), color (String), value (int);
        `validMoves` parsed gracefully (non-Map entries silently skipped;
        missing key treated as empty list)
    -   `==` uses list equality helper; `hashCode`, `toString`
-   `mobile/lib/features/game/models/pawn_moved.dart`:
    -   `PawnMoved(matchId, color, pawnIndex, toPosition, capturedColor?,
        capturedPawnIndex?)` — payload of the `pawn_moved` Socket.IO event
        (Phase 6.2); optional capture fields are null when no capture occurred
    -   `fromJson` — validates required fields; reads optional fields as
        nullable
    -   `==`, `hashCode`, `toString`
-   `mobile/lib/features/game/models/turn_changed.dart`:
    -   `TurnChanged(matchId, nextTurn)` — payload of the `turn_changed`
        Socket.IO event (Phase 6.1 / 6.2)
    -   `fromJson` — validates both fields; throws `FormatException` if missing
    -   `==`, `hashCode`, `toString`
-   `mobile/lib/features/game/services/game_service.dart`:
    -   `GameService` — constructor DI (`SocketClient` required parameter)
    -   `startListening()` — registers handlers for `dice_rolled`, `pawn_moved`,
        `turn_changed`; clears stale handlers before re-registering (idempotent)
    -   `stopListening()` — unregisters all three handlers (safe before
        `startListening` is called)
    -   `rollDice(matchId)` — emits `roll_dice { matchId }` to the server
    -   `movePawn(matchId, pawnIndex)` — emits `move_pawn { matchId, pawnIndex }`
    -   `onDiceRolled` / `onPawnMoved` / `onTurnChanged` — broadcast streams;
        malformed incoming payloads silently dropped
    -   `dispose()` — calls `stopListening`, closes all three `StreamController`s;
        idempotent (safe to call multiple times)
    -   `GameException` typed exception for service-level errors

**Flutter — new test files**
-   `mobile/test/features/game/models/valid_move_test.dart` — 10 tests
    (fromJson correct/variants/FormatException; equality; hashCode; toString)
-   `mobile/test/features/game/models/dice_rolled_test.dart` — 12 tests
    (fromJson with/without validMoves/FormatException/malformed-list-entry;
    equality including list comparison; hashCode; toString)
-   `mobile/test/features/game/models/pawn_moved_test.dart` — 13 tests
    (fromJson with/without capture/optional field combinations/FormatException;
    equality; hashCode; toString)
-   `mobile/test/features/game/models/turn_changed_test.dart` — 11 tests
    (fromJson all colours/FormatException; equality; hashCode; toString;
    type inequality)
-   `mobile/test/features/game/game_service_test.dart` — 27 tests
    (rollDice/movePawn emits; startListening/stopListening handler
    registration/cleanup; onDiceRolled/onPawnMoved/onTurnChanged stream
    delivery with/without capture; malformed payload drop; dispose lifecycle;
    GameException message)

**No backend changes** — Phase 6.3 is Flutter only.

**No new packages** — no changes to `pubspec.yaml`.

**No new database tables** — models are pure Dart value objects.

**Verified**
-   `flutter analyze` — no issues ✅
-   `flutter test` (new tests) — 73/73 passing ✅
-   Backend build — clean ✅
-   TypeScript typecheck — clean ✅

------------------------------------------------------------------------

## v0.16.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 6.2 complete — Move Pawn, Captures & Win Detection (backend
`move_pawn` handler, pawn movement, capture logic, win detection,
extra turn on 6, integration tests)

### Details

**Backend — modified files**
-   `backend/src/socket/game_engine.ts`:
    -   Added `import { pool }` from `../db/index.js` — needed for DB write
        on match win
    -   Updated module-level JSDoc to reflect Phase 6.1 / 6.2 scope
    -   `handleMovePawn(socket, io, data)` — new exported async function:
        -   Validates: `matchId` present, `pawnIndex` integer 0–3, game state
            exists, caller is a participant, `currentTurn === player.color`,
            `phase === 'waiting_move'`, `pawnIndex` present in `validMoves`
        -   Applies move: `player.pawns[pawnIndex].position = move.toPos`
        -   Capture detection (positions 1–51, shared track only):
            converts `toPos` to absolute via `relativeToAbsolute`; skips
            safe squares (`isAbsoluteSafe`); iterates opponent pawns on shared
            track; sends first matching pawn back to position 0
        -   Emits `pawn_moved { matchId, color, pawnIndex, toPosition,
            capturedColor?, capturedPawnIndex? }` to room via `io.to(matchId)`
        -   Win detection: `player.pawns.every(p => p.position === HOME_FINISHED)`
            → `pool.query` UPDATE matches (status finished, winner_id,
            finished_at); `clearGameState(matchId)`;
            `io.to(matchId).emit('game_over', { matchId, winnerId, reason: 'completed' })`
            → returns `{ matchId }` to signal win to caller
        -   Next-turn logic: `state.diceValue === 6` → extra turn (same
            colour); else `nextPlayerColor(state)` → pass turn; resets
            `diceValue`, `validMoves`, `phase` to `waiting_roll`; emits
            `turn_changed { matchId, nextTurn }`
        -   Returns `undefined` in all non-win paths
-   `backend/src/socket/game_lobby.ts`:
    -   Added `handleMovePawn` to named imports from `./game_engine.js`
    -   Registered `move_pawn` event in `setupGameLobbyHandlers`:
        calls `handleMovePawn`; on resolved `{ matchId }` (win) cleans up
        `activeGameBySocketId` entries for that match

**Backend — new files**
-   `backend/tests/phase62_move.mjs` — 8 Socket.IO integration tests:
    -   Test 1: `pawn_moved` emitted to both sockets with correct payload
        (matchId, color, pawnIndex, toPosition identical on both)
    -   Test 2: `move_pawn` without matchId → error event
    -   Test 3: `move_pawn` before rolling (phase `waiting_roll`) → error
    -   Test 4: `move_pawn` when not your turn → error mentions 'turn'
    -   Test 5: `pawnIndex` out of range (4) → error mentions pawnIndex constraint
    -   Test 6: non-participant socket → error event
    -   Test 7: extra turn after rolling 6 — `turn_changed.nextTurn` equals
        same colour as mover; both sockets receive same `nextTurn`
    -   Test 8: capture — plays until a capture occurs (≤ 200 turns);
        asserts `capturedColor` is a string, `capturedPawnIndex` is a number
        in 0–3, and `capturedColor !== color` (opponent captured)

**No Flutter changes** — Phase 6.3 covers Flutter models + GameService.

**No new packages** — pure TypeScript game logic.

**No new database tables** — win persisted to existing `matches` table.

**Verified**
-   Backend build — clean (esbuild, no TypeScript errors) ✅
-   Backend typecheck (tsc --noEmit) — clean ✅

------------------------------------------------------------------------

## v0.15.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 6.1 complete — Ludo Game State Engine + roll_dice (backend game
engine, in-memory state, dice rolling with valid-move computation, automatic
turn passing, integration tests)

### Details

**Backend — new files**
-   `backend/src/socket/game_engine.ts` — new module:
    -   `PawnColor`, `ValidMove`, `PawnState`, `PlayerState`, `GamePhase`,
        `LudoGameState` types exported for use by Phase 6.2+
    -   `SAFE_ABSOLUTE_POSITIONS` Set — 8 safe squares (4 entry squares +
        4 mid-segment stars) encoded as 0-indexed absolute track positions
    -   `gameStateMap` — `Map<string, LudoGameState>` (module-level, no
        singleton class)
    -   `createGameState(matchId, players, firstTurn)` — initialises all
        4 pawns per player at position 0 (yard); called by `game_lobby.ts`
        immediately after `game_start` is emitted
    -   `getGameState(matchId)` / `clearGameState(matchId)` — lifecycle
        helpers for Phase 6.2+ and forfeit cleanup
    -   `relativeToAbsolute(relPos, color)` — converts colour-relative
        track position to 0-indexed absolute position; used by Phase 6.2
        capture detection
    -   `isAbsoluteSafe(absPos)` — returns true for safe-square positions
    -   `nextPlayerColor(state)` — returns the opposing player's colour
    -   `computeValidMoves(player, diceValue)` (private) — position 0
        requires dice = 6 to release pawn (toPos = 1); positions 1–56
        advance by diceValue if toPos ≤ 57; position 57 skipped
    -   `handleRollDice(socket, io, data)` — validates matchId present,
        game state exists, caller is a participant, it is their turn,
        phase is `waiting_roll`; rolls server-side 1–6; emits
        `dice_rolled { matchId, color, value, validMoves }` to room;
        if validMoves empty → passes turn automatically and emits
        `turn_changed { matchId, nextTurn }`; if validMoves non-empty →
        transitions phase to `waiting_move`
-   `backend/tests/phase61_dice.mjs` — 5 Socket.IO integration tests:
    -   Test 1: `dice_rolled` emitted to both sockets with valid shape
        (matchId, color matches firstTurn, value 1–6, validMoves array)
    -   Test 2: missing matchId → error event
    -   Test 3: non-turn player rolls → error "not your turn"
    -   Test 4: non-participant socket rolls → error event
    -   Test 5: phase transition — no valid moves emits `turn_changed`
        (dice ≠ 6 branch); valid moves transitions to `waiting_move` and
        re-roll emits error (dice = 6 branch); both branches verified

**Backend — modified files**
-   `backend/src/socket/game_lobby.ts`:
    -   Added import of `createGameState`, `clearGameState`,
        `handleRollDice`, `PawnColor` from `game_engine.js`
    -   `handleGameStart` — SELECT query extended to also fetch `user_id`
        from `match_players`; calls `createGameState` after emitting
        `game_start`
    -   `finishMatchByForfeit` — calls `clearGameState(matchId)` when the
        match finishes (forfeit or disconnect) so stale state is not kept
    -   `setupGameLobbyHandlers` — registers `roll_dice` event handler

**No Flutter changes** — Phase 6.1 is a backend-only sub-phase.  Flutter
integration begins in Phase 6.3.

**No new packages** — pure TypeScript game logic, no additional dependencies.

**No new database tables** — game state is in-memory; the existing `matches`
table stores the final result.

**Verified**
-   Backend build — clean (esbuild, no TypeScript errors) ✅
-   Backend typecheck (tsc --noEmit) — clean ✅

------------------------------------------------------------------------

## v0.14.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 5.6 complete — Forfeit & Game Termination (backend forfeit/auto-forfeit
socket handler, GameOver model, GameLobbyService forfeit+onGameOver,
GameScreen stateful with game-over overlay, MainShell wired end-to-end)

### Details

**Backend — modified files**
-   `backend/src/socket/game_lobby.ts` — added `finishMatchByForfeit(io,
    matchId, forfeitingUserId, reason)` shared helper: guards on
    `in_progress` status (idempotent), queries opponent from `match_players`,
    updates `matches SET status='finished', winner_id, finished_at=NOW()`,
    clears `activeGameBySocketId` entries, emits `game_over { matchId,
    winnerId, reason }` to all players in room; added `handleForfeit(socket,
    io, data)`: validates matchId, verifies participant via DB, calls helper;
    added `activeGameBySocketId` Map (socketId → matchId) populated after
    `game_start` is emitted; extended `handleDisconnectForLobby` to also check
    `activeGameBySocketId` and trigger auto-forfeit with reason `'disconnect'`;
    registered `forfeit` event handler in `setupGameLobbyHandlers`

**Backend — new files**
-   `backend/tests/phase56_forfeit.mjs` — 5 Socket.IO integration tests:
    forfeit emits game_over to both sockets (matchId, winnerId, reason
    validated), forfeit without matchId emits error, forfeit from
    non-participant emits error, double-forfeit idempotent (no duplicate
    game_over within 1 s), disconnect during in_progress triggers auto-forfeit

**Flutter — new files**
-   `mobile/lib/features/game/models/game_over.dart` — `GameOver(matchId,
    winnerId, reason)` immutable model; `fromJson` with missing-field guard;
    `==`, `hashCode`, `toString`

**Flutter — modified files**
-   `mobile/lib/features/matchmaking/services/game_lobby_service.dart` —
    `onGameOver` broadcast `Stream<GameOver>` added; `forfeit(matchId)` emits
    `forfeit` socket event; `_handleGameOver` handler; `joinRoom` registers
    `game_over` handler; `leaveRoom`/`dispose` clear handler and close stream
-   `mobile/lib/features/game/screens/game_screen.dart` — upgraded from
    `StatelessWidget` to `StatefulWidget`; `gameLobbyService: GameLobbyService`
    required parameter (replaces `onForfeit` callback); subscribes to
    `onGameOver` stream in `initState`; `_forfeiting` bool state — forfeit
    button shows spinner while waiting for server response; `_gameOver`
    state — non-null once server emits `game_over`; `_ForfeitButton` updated:
    `onPressed` null when forfeiting or game over, spinner shown; added
    `_GameOverOverlay` private widget — full-screen tinted backdrop,
    `game_over_card` with title (YOU WIN / YOU LOSE), subtitle (forfeit /
    disconnect), `game_over_continue_button` fires `onGameOver(GameOver)`
    callback; `onGameOver(GameOver)` replaces `onForfeit` — called when player
    dismisses overlay, parent handles navigation; keys added:
    `game_over_overlay`, `game_over_card`, `game_over_title`,
    `game_over_subtitle`, `game_over_continue_button`, `forfeit_spinner`,
    `forfeit_label`
-   `mobile/lib/navigation/main_shell.dart` — `_onGameStart` now passes
    `gameLobbyService: widget.gameLobbyService` to `GameScreen`; `onGameOver:
    _onGameOver` replaces `onForfeit`; `_onGameOver(GameOver)` calls
    `Navigator.popUntil((r) => r.isFirst)` to dismiss GameScreen +
    GameLobbyScreen in one step

**Flutter — updated tests**
-   `mobile/test/features/game/game_screen_test.dart` — rewritten for
    `StatefulWidget` API: `_FakeSocketClient`, `_FakeGameLobbyService` fakes;
    25 tests total (all Phase 5.5 tests preserved + 10 new Phase 5.6 tests):
    forfeit emits socket event, spinner visible while forfeiting, button
    disabled while forfeiting, overlay absent initially, overlay appears on
    game_over, card/title/subtitle/continue present, CONTINUE fires onGameOver
    with correct payload, overlay disables forfeit button
-   `mobile/test/features/matchmaking/game_lobby_service_test.dart` —
    extended: 5 new tests: `joinRoom` registers `game_over` handler; `game_over`
    event emits `GameOver` to stream (forfeit reason); disconnect reason
    forwarded; malformed payload dropped; `leaveRoom` removes `game_over`
    handler; `dispose` closes `onGameOver` stream
-   `mobile/test/navigation/main_shell_test.dart` — updated `_FakeGameLobbyService`
    to include `onGameOver` stream and `simulateGameOver`; updated test that
    pushes `GameScreen` to pass `gameLobbyService`; added test that game-over
    overlay CONTINUE pops the stack to shell root

**Architecture decisions**
-   `finishMatchByForfeit` is idempotent — the `status = 'in_progress'` guard
    in the UPDATE ensures a second call on an already-finished match is a no-op.
    The double-forfeit test confirms no duplicate `game_over` events are emitted.
-   Auto-forfeit on disconnect uses `activeGameBySocketId` (populated after
    game_start) so only sockets that have received `game_start` can trigger it.
    Lobby-phase disconnects continue to use the existing `opponent_left` path.
-   `GameScreen` receives `gameLobbyService` directly rather than threading an
    `onForfeit` callback through the parent — this keeps the forfeit→server→
    game_over→overlay flow self-contained in the screen with no round-trip
    through `MainShell`.
-   `onGameOver` callback (called after overlay dismiss) keeps navigation in
    the parent — consistent with the "screen never calls Navigator" rule.

**Docs updated**
-   `07_SOCKET_EVENTS.md` — `forfeit` event documented (direction, payload,
    behaviour); `game_over` entry expanded (direction, payload, reason values)
-   `02_PROJECT_STATUS.md` — Phase 5.6 added, version bumped to v0.14.0
-   `12_ROADMAP.md` — Phase 5.6 marked ✅
-   `09_CHANGELOG.md` — this entry

**Verified**
-   Backend build — clean (esbuild, no TypeScript errors) ✅
-   Flutter SDK not available in Replit environment — flutter analyze and
    flutter test deferred to local/CI environment ⚠️

------------------------------------------------------------------------

## v0.13.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 5.5 complete — Game Session Initiation (backend game_start emission, GameStarted model, GameScreen placeholder, GameLobbyService/Screen/MainShell wired end-to-end)

### Details

**Backend — modified files**
-   `backend/src/socket/game_lobby.ts` — added `handleGameStart(io, matchId)`:
    queries `match_players` for both colours, randomly selects `firstTurn`,
    updates `matches SET status = 'in_progress', started_at = NOW()`, emits
    `game_start { matchId, firstTurn }` to all sockets in the room.
    Scheduled via `setTimeout(2500)` inside `handleJoinRoom` immediately after
    emitting `room_ready`.

**Flutter — new files**
-   `mobile/lib/features/matchmaking/models/game_started.dart` — `GameStarted(matchId, firstTurn)` with `fromJson`; `const` constructor
-   `mobile/lib/features/game/screens/game_screen.dart` — `GameScreen(gameStarted, matchFound, onForfeit, onSessionExpired)`; stateless; dark arcade palette; `_FirstTurnBanner`, `_MatchInfoCard`, `_PlaceholderBoard`, `_ForfeitButton` private widgets; interactive keys: `game_screen_app_bar`, `forfeit_button`, `placeholder_board_text`, `first_turn_banner`, `match_info_card`
-   `mobile/test/features/game/game_screen_test.dart` — widget tests: smoke, AppBar renders, first-turn banner (go-first / opponent-first), forfeit button present and fires callback, placeholder board text, match info card
-   `mobile/test/navigation/main_shell_test.dart` — extended: `_FakeGameLobbyService` exposes `simulateGameStarted`; test verifies that simulating `game_start` from lobby pushes `GameScreen`

**Flutter — modified files**
-   `mobile/lib/features/matchmaking/services/game_lobby_service.dart` —
    `onGameStart` broadcast `Stream<GameStarted>` added; `_gameStartedController`
    `StreamController`; `_handleGameStart(dynamic)` private handler; `joinRoom`
    registers/clears `game_start` handler; `leaveRoom` and `dispose` clean up
    the new stream
-   `mobile/lib/features/matchmaking/screens/game_lobby_screen.dart` —
    `onGameStart(GameStarted, MatchFound)` required callback added; `_gameStartedSub`
    `StreamSubscription`; `_onGameStarted` calls the callback; subscription
    created in `initState`, cancelled in `dispose`
-   `mobile/lib/navigation/main_shell.dart` — `_onGameStart(GameStarted, MatchFound)`
    method added; pushes `GameScreen` via `MaterialPageRoute`; `GameScreen.onForfeit`
    calls `Navigator.popUntil((r) => r.isFirst)` to return to shell root

**Architecture decisions**
-   `GameScreen` is a stateless placeholder; all game logic (board, dice,
    timer, pawn movement) is deferred to Phase 6.
-   Forfeit pops the entire stack back to the shell root (`popUntil isFirst`)
    so both `GameScreen` and `GameLobbyScreen` are dismissed in one step.
-   `GameLobbyScreen` stays visible for the 2.5 s window between `room_ready`
    and `game_start`; no spinner or timeout added at this phase.

**Docs updated**
-   `07_SOCKET_EVENTS.md` — `game_start` entry expanded with direction,
    timing, and full payload documentation
-   `02_PROJECT_STATUS.md` — Phase 5.5 added, version bumped to v0.13.0
-   `12_ROADMAP.md` — Phase 5.5 marked ✅
-   `09_CHANGELOG.md` — this entry

**Verified**
-   Backend build — clean (esbuild, no TypeScript errors) ✅
-   Flutter SDK not available in Replit environment — flutter analyze and
    flutter test deferred to local/CI environment ⚠️

------------------------------------------------------------------------

## v0.12.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 5.4 complete — Flutter Game Lobby (backend join_room/leave_room socket handlers, GameLobbyService, GameLobbyScreen with 5 states, 35 new tests, 269/269 passing)

### Details

**Backend — new files**
-   `backend/src/socket/game_lobby.ts` — `setupGameLobbyHandlers(io)`: `join_room` handler verifies the authenticated player is a match participant (SQL query), joins Socket.IO room, tracks in-memory readiness (`roomJoinedSockets` Map), emits `room_joined` on entry, emits `room_ready` to both players when count ≥ 2; `leave_room` handler emits `room_left` to leaving player and `opponent_left` to remaining player; disconnect cleanup iterates `roomJoinedSockets` and emits `opponent_left` to remaining players

**Backend — modified files**
-   `backend/src/socket/index.ts` — imports and calls `setupGameLobbyHandlers(io)` after `setupMatchmakingHandlers(io)`

**Flutter — new files**
-   `mobile/lib/features/matchmaking/models/room_ready.dart` — `RoomReady(matchId: String)` with `fromJson`
-   `mobile/lib/features/matchmaking/services/game_lobby_service.dart` — `GameLobbyService(socketClient)`; `joinRoom(matchId)`: throws `SessionExpiredException` if socket disconnected, clears stale handlers, registers `room_ready`/`opponent_left` handlers, emits `join_room`; `leaveRoom(matchId)`: emits `leave_room`, clears handlers, disconnects socket; `onRoomReady` broadcast stream; `onOpponentLeft` broadcast stream; `GameLobbyException` typed exception; `dispose()` closes streams
-   `mobile/lib/features/matchmaking/screens/game_lobby_screen.dart` — `GameLobbyScreen(gameLobbyService, matchFound, onSessionExpired, onLeaveRoom)`; 5 states via `AnimatedSwitcher` 280 ms: joining (spinner + "Joining game room…"), waiting (match info card + waiting indicator + leave button), ready (green check + "Room Ready!" + match info + disabled start button), opponentLeft (amber banner + leave button), error (red banner + leave button); private widgets: `_MatchInfoCard`, `_LobbyAvatar`, `_LobbyColorChip`, `_LeaveButton`; interactive keys: `joining_view`, `joining_spinner`, `joining_text`, `waiting_view`, `waiting_text`, `match_info_card`, `opponent_name`, `assigned_color`, `room_code`, `ready_view`, `ready_text`, `ready_subtitle`, `start_game_button`, `opponent_left_view`, `opponent_left_banner`, `opponent_left_text`, `error_view`, `error_banner`, `error_message`, `leave_lobby_button`, `leave_button`, `game_lobby_app_bar`
-   `mobile/test/features/matchmaking/game_lobby_service_test.dart` — 16 unit tests: joinRoom emits join_room with matchId, throws SessionExpiredException when disconnected, registers handlers, clears stale handlers; room_ready → onRoomReady stream, malformed payload dropped; opponent_left → onOpponentLeft stream, malformed payload dropped; leaveRoom emits leave_room, removes handlers, disconnects socket, safe when disconnected; dispose closes both streams
-   `mobile/test/features/matchmaking/game_lobby_screen_test.dart` — 19 widget tests: smoke, joining state, waiting state after join, opponent name, room code, color chip, leave button in waiting, joinRoom called, room_ready → ready state, "Room Ready!" text, match info card, start button, opponent_left → opponentLeft state, leave button in opponentLeft, tapping leave calls onLeaveRoom, AppBar back calls onLeaveRoom, SessionExpiredException → onSessionExpired, GameLobbyException → error state, error leave button

**Flutter — modified files**
-   `mobile/lib/features/matchmaking/screens/matchmaking_screen.dart` — `onMatchReady(MatchFound)` callback added as required parameter; PLAY button changed from `onPressed: _reset` to `onPressed: () { final match = _matchFound!; _reset(); widget.onMatchReady(match); }`
-   `mobile/lib/navigation/main_shell.dart` — `gameLobbyService: GameLobbyService` required parameter; `_onMatchReady(MatchFound)` method pushes `GameLobbyScreen` via `Navigator.push`; `MatchmakingScreen` receives `onMatchReady: _onMatchReady`
-   `mobile/lib/navigation/auth_gate.dart` — `gameLobbyService: GameLobbyService` required parameter threaded to `MainShell`
-   `mobile/lib/main.dart` — `GameLobbyService(socketClient: socketClient)` constructed; `OneLudoApp` gains `gameLobbyService` required parameter; passed to `AuthGate`
-   `mobile/test/features/matchmaking/matchmaking_screen_test.dart` — `_pump` helper gains optional `onMatchReady` parameter; all existing 15 tests pass unchanged
-   `mobile/test/navigation/main_shell_test.dart` — added `_FakeGameLobbyService`; `_pump` gains `gameLobbyService`
-   `mobile/test/navigation/auth_gate_test.dart` — added `_FakeGameLobbyService`; `_pump` gains `gameLobbyService`
-   `mobile/test/widget_test.dart` — added `_FakeGameLobbyService`; both `OneLudoApp` calls gain `gameLobbyService`

**Architecture decisions**
-   `GameLobbyService` reuses the same `SocketClient` instance as `MatchmakingService` — the socket is already connected after matchmaking and remains open until `leaveRoom` disconnects it. The next `MatchmakingService.joinQueue()` call reconnects transparently.
-   `GameLobbyScreen` is pushed via `Navigator.push` from `MainShell._onMatchReady`, making it a full-screen route that hides the bottom navigation bar during the lobby — correct UX for a pre-game waiting room.
-   `MatchmakingScreen.onMatchReady` callback calls `_reset()` first so the screen returns to idle state when the user navigates back from the lobby.
-   `dispose` of `GameLobbyScreen` calls `leaveRoom` fire-and-forget — idempotent, correct cleanup on back-navigation or logout.
-   `start_game_button` is present but disabled in Phase 5.4; Phase 6 (Classic Ludo) will enable it.

**Docs updated**
-   `07_SOCKET_EVENTS.md` — `join_room`, `room_joined`, `room_ready`, `leave_room`, `room_left`, `opponent_left` events documented
-   `02_PROJECT_STATUS.md` — Phase 5.4 added, version bumped to v0.12.0
-   `12_ROADMAP.md` — Phase 5.4 marked ✅
-   `09_CHANGELOG.md` — this entry

**Verified**
-   flutter analyze — no issues ✅
-   flutter test — 269/269 passed (234 prior + 35 new game lobby tests, zero regressions) ✅
-   Backend build — clean (esbuild, no TypeScript errors) ✅
-   No new pubspec dependencies added ✅

------------------------------------------------------------------------

## v0.11.0

### Date

2026-07-19

### Author

Replit Agent

### Summary

Phase 5.3 complete — Flutter Matchmaking UI (MatchmakingScreen with 4 states, DI threading through main.dart/AuthGate/MainShell, 15 widget tests)

### Details

**Flutter — new files**
-   `mobile/lib/features/matchmaking/screens/matchmaking_screen.dart` — `MatchmakingScreen(matchmakingService, onSessionExpired)`; four states: idle (FIND MATCH button), searching (spinner + MM:SS elapsed + CANCEL), matchFound (opponent card + room code + colour chip + PLAY), error (error banner + TRY AGAIN); `AnimatedSwitcher` 280 ms between states; subscribes to `onMatchFound` broadcast stream in `initState`; starts a `Timer.periodic(1s)` during search; cancels timer + stream subscription + calls `leaveQueue()` (fire-and-forget) in `dispose`; `SessionExpiredException` during `joinQueue` fires `onSessionExpired` callback immediately; `MatchmakingException` shows error banner
-   Private widgets: `_OpponentAvatar` (circular avatar, gold initials fallback), `_ColorChip` (pill chip mapping color name → Flutter Color)
-   `mobile/test/features/matchmaking/matchmaking_screen_test.dart` — 15 widget tests: smoke, idle keys, tap FIND MATCH → searching state, elapsed timer increments, cancel → idle, leaveQueue tracked on cancel, match_found event → match found state, opponent name rendered, room code rendered, color chip uppercase, PLAY → idle reset, SessionExpiredException → onSessionExpired callback, MatchmakingException → error banner, error banner message, TRY AGAIN → idle

**Flutter — modified files**
-   `mobile/lib/main.dart` — constructs `SocketClient(tokenProvider: storage.getAccessToken)` and `MatchmakingService(apiClient, socketClient)`; `OneLudoApp` gains `matchmakingService` required parameter; threads it to `AuthGate`
-   `mobile/lib/navigation/auth_gate.dart` — `AuthGate` gains `matchmakingService: MatchmakingService` required parameter; threads it to `MainShell`
-   `mobile/lib/navigation/main_shell.dart` — `MainShell` gains `matchmakingService: MatchmakingService` required parameter; `IndexedStack` index 0 replaced: `HomeScreen()` → `MatchmakingScreen(matchmakingService: widget.matchmakingService, onSessionExpired: widget.onLogout)`; `HomeScreen` file preserved (Phase 3 tests remain green)
-   `mobile/test/navigation/main_shell_test.dart` — added `_FakeSocketClient`, `_FakeMatchmakingService`; `_pump()` injects `_FakeMatchmakingService()`; test 3 assertion changed from `HomeScreen` → `MatchmakingScreen`
-   `mobile/test/navigation/auth_gate_test.dart` — added `_FakeSocketClient`, `_FakeMatchmakingService`; `_pump()` injects `_FakeMatchmakingService()`
-   `mobile/test/widget_test.dart` — added `_FakeSocketClient`, `_FakeMatchmakingService`; both `OneLudoApp(...)` calls gain `matchmakingService: _FakeMatchmakingService()`

**Architecture decisions**
-   `onSessionExpired` in `MatchmakingScreen` wires directly to `MainShell.onLogout`, which propagates to `AuthGate._onLogout`. No new callback chain introduced — the existing logout path handles socket JWT expiry naturally.
-   `MatchmakingService` is NOT modified (Phase 5.2 is sealed). The screen consumes it via its public API only.
-   `HomeScreen` is not deleted — its existing 4 unit tests continue to pass against the original file.
-   `dispose` calls `leaveQueue()` as fire-and-forget because `MatchmakingScreen` lives inside an `IndexedStack` (state preserved across tabs); dispose only fires on full `MainShell` teardown (logout), at which point leaving the queue is correct cleanup regardless.
-   The elapsed `Timer.periodic` is cancelled in both `leaveQueue` callback and `dispose` to prevent `setState` calls on unmounted widget.

**Verified**
-   flutter analyze — no issues ✅
-   flutter test — 234/234 passed (217 prior + 15 new matchmaking screen tests, zero regressions) ✅
-   No new pubspec dependencies added ✅

------------------------------------------------------------------------

## v0.10.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 5.1 complete — Matchmaking Backend Foundation (in-memory queue, Socket.IO auth middleware, match creation, REST status endpoint)

### Details

**Database — new migrations**
-   `backend/src/db/migrations/0007_create_matches_table.sql` — matches table: UUID PK, room_code UNIQUE VARCHAR(8), mode/status CHECK constraints, entry_points NUMERIC, player_count, winner_id FK → users, started_at/finished_at/created_at; indexes on status, room_code, created_at DESC
-   `backend/src/db/migrations/0008_create_match_players_table.sql` — match_players table: UUID PK, match_id FK CASCADE, user_id FK CASCADE, color CHECK IN (red/blue/green/yellow), final_rank, earned_points, joined_at; UNIQUE (match_id, user_id), UNIQUE (match_id, color); indexes on match_id, user_id

**Backend — new files**
-   `backend/src/services/matchmaking.queue.ts` — in-memory Map queue; exported functions: enqueue, dequeue, getEntry, isQueued, queueSize, dequeueOpponent (synchronous, removes opponent before any await — race-condition safe), removeStaleEntries (called by cleanup interval)
-   `backend/src/services/match.service.ts` — createMatch(player1, player2): atomic PostgreSQL transaction (collision-free room code generation with up to 10 retries, INSERT match, INSERT two match_players with random color assignment, COMMIT/ROLLBACK); findMatchById()
-   `backend/src/controllers/matchmaking.controller.ts` — getQueueStatus(): REST read-only handler returning inQueue, joinedAt, queueSize
-   `backend/src/routes/matchmaking.ts` — GET /match/queue/status behind authenticate middleware
-   `backend/src/socket/matchmaking.ts` — setupMatchmakingHandlers(io): registers JWT auth middleware (verifyAccessToken + findById, sets socket.data.user); find_match handler (dequeueOpponent synchronously → create match + emit match_found to both, or enqueue self → emit queue_joined; idempotent reconnect path); leave_queue handler (dequeue + emit queue_left, idempotent); disconnect handler (guards on socketId before dequeuing)
-   `backend/tests/phase51_matchmaking.sh` — 10 REST integration tests
-   `backend/tests/phase51_matchmaking_socket.mjs` — 31 Socket.IO integration tests using socket.io-client

**Backend — modified files**
-   `backend/src/socket/index.ts` — calls setupMatchmakingHandlers(io) after creating the SocketIOServer
-   `backend/src/routes/index.ts` — mounts matchmakingRouter
-   `backend/src/index.ts` — adds queue stale-entry cleanup interval (5 min, .unref())

**New devDependency**
-   `socket.io-client` — added as backend devDependency for Socket.IO integration testing

**Architecture decisions**
-   Queue join/leave is Socket.IO-only (not REST). REST exposes only read-only status. This design ensures the socketId is always available when match_found must be emitted.
-   Race-condition safety: dequeueOpponent is synchronous and runs before any await. Both players are removed from the Map before the DB write begins — no third player can steal either slot during the async operation.
-   On DB failure during match creation: the opponent is restored to the queue so they are not lost; the joining player receives an error event.
-   Socket auth middleware fetches full_name and avatar from DB (not stored in JWT) so the match_found opponent payload is immediately available without an extra DB round-trip at match time.
-   Disconnect handler guards on socketId so a reconnected player with a fresh socket does not accidentally evict their own new queue entry.

**Verified**
-   pnpm run build — clean ✅
-   Migrations 0007–0008 applied ✅
-   Phase 5.1 REST tests — 10/10 passed ✅
-   Phase 5.1 Socket tests — 31/31 passed ✅
-   Phase 3.1 — 35/35 (zero regressions) ✅
-   Phase 3.3 — 25/25 (zero regressions) ✅
-   Phase 3.6 — 21/21 (zero regressions) ✅
-   Phase 4.1 — 31/31 (zero regressions) ✅
-   Phase 4.4 — 50/50 (zero regressions) ✅

------------------------------------------------------------------------

## v3.0.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 3 complete — Flutter Navigation Shell (AuthGate, MainShell, HomeScreen, updated main.dart)

### Details

**Flutter — new files**
-   `mobile/lib/features/home/screens/home_screen.dart` — `HomeScreen` placeholder widget:
    -   Pure `StatelessWidget`; no service dependencies
    -   Dark `_kBg` background (`0xFF0D0D1A`); centred column layout
    -   Gold game controller icon (`Icons.sports_esports`, `Key('home_icon')`)
    -   Title "1 Minute Ludo" (`Key('home_title')`) and tagline "Game lobby coming soon" (`Key('home_tagline')`)
    -   Will be replaced with the live lobby in a later phase
-   `mobile/lib/navigation/main_shell.dart` — `MainShell` stateful navigation shell:
    -   Constructor: `profileService`, `changePasswordService`, `walletService`, `paymentService`, `onLogout`
    -   `BottomNavigationBar` (`Key('bottom_nav_bar')`) with three tabs: Home (sports\_esports icon), Profile (person icon), Wallet (account\_balance\_wallet icon); `BottomNavigationBarType.fixed`; selected colour `_kPrimary`, unselected `_kTextSecondary`, background `_kSurface`
    -   `IndexedStack` (`Key('main_shell_body')`) — all three screens (`HomeScreen`, `ProfileScreen`, `WalletScreen`) live in the stack; only the active one is visible; state is preserved across tab switches
    -   `AppBar` (`Key('main_shell_app_bar')`) — gold title tracks the active tab label; trailing `IconButton` (`Key('logout_button')`, tooltip "Log out") fires the `onLogout` callback; 1 px `_kBorder` bottom divider
    -   No `Navigator` calls; routing is the parent's responsibility
-   `mobile/lib/navigation/auth_gate.dart` — `AuthGate` stateful entry-point widget:
    -   Constructor: `authService`, `profileService`, `changePasswordService`, `walletService`, `paymentService`
    -   Three-state machine (`_GateState`: `checking` → loading screen; `unauthenticated` → auth screens; `authenticated` → `MainShell`)
    -   `initState` calls `AuthService.isLoggedIn()` and transitions accordingly
    -   Routes `LoginScreen` ↔ `RegisterScreen` internally via a `_AuthView` enum — no `Navigator` calls
    -   `_onAuthSuccess` (fired by login or register success) → transitions to `authenticated`
    -   `_onLogout` → sets `checking` state, awaits `AuthService.logout()`, transitions to `unauthenticated`; `LoginScreen` shown after logout regardless of server response (logout implementation always clears local tokens)
    -   `_LoadingScreen` private widget: `_kBg` background, centred `CircularProgressIndicator` (`Key('auth_gate_loading')`, colour `_kPrimary`)

**Flutter — updated files**
-   `mobile/lib/main.dart`:
    -   `main()` is now `async`; calls `WidgetsFlutterBinding.ensureInitialized()`
    -   Constructs shared `TokenStorage` (const) and `ApiClient`, then all five services with constructor DI
    -   `OneLudoApp` is no longer const-constructable; accepts all five services as required parameters
    -   `home:` is now `AuthGate(...)` — `_PlaceholderHome` removed
    -   MaterialApp theme unchanged

**Flutter — new tests**
-   `mobile/test/features/home/home_screen_test.dart` — 4 widget tests: smoke, title text, tagline text, game controller icon
-   `mobile/test/navigation/main_shell_test.dart` — 10 widget tests: smoke, BottomNavigationBar with 3 labelled items, Home tab default (HomeScreen visible + AppBar title), AppBar title → "Profile" after Profile tap, ProfileScreen in stack, AppBar title → "Wallet" after Wallet tap, WalletScreen in stack, round-trip tab switch, logout button fires callback, logout button tooltip
-   `mobile/test/navigation/auth_gate_test.dart` — 9 widget tests: smoke, loading indicator while session check pending, LoginScreen when not logged in, register link → RegisterScreen, login link → LoginScreen (back), MainShell when already logged in, login form success → MainShell, register form success → MainShell, logout → LoginScreen

**Flutter — updated tests**
-   `mobile/test/widget_test.dart` — updated `OneLudoApp` instantiation to pass fake services; added second test: "App shows LoginScreen for unauthenticated users"

**Results**
-   flutter analyze — no issues ✅
-   flutter test — 188/188 passed (164 prior + 24 new, zero regressions) ✅

------------------------------------------------------------------------

## v2.6.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 2.6 complete — Flutter Auth UI Screens (LoginScreen, RegisterScreen, AuthTextField)

### Details

**Flutter — new files**
-   `mobile/lib/features/auth/widgets/auth_text_field.dart` — `AuthTextField` shared reusable styled `TextFormField`:
    -   Dark surface fill (`0xFF1A1A2E`), focus border (`_kPrimary`), error border (`_kError`), secondary label colour — palette consistent with `ProfileScreen` and `WalletScreen`
    -   Optional `validator` parameter surfaces inline validation messages below the field via Flutter's `Form` / `FormState` API
    -   Optional `onToggleObscure` parameter renders a visibility toggle icon button in the suffix — used for password fields
    -   Exposes `keyboardType`, `textInputAction`, `onFieldSubmitted`, `enabled`, `autocorrect`, `enableSuggestions` for full field configurability
-   `mobile/lib/features/auth/screens/login_screen.dart` — `LoginScreen` stateful widget:
    -   Callbacks: `onLoginSuccess(UserProfile)`, `onRegisterPressed` — no `Navigator` calls; parent decides navigation
    -   Branding area: gold game controller icon, "1 Minute Ludo" title, "PLAY · WIN · REPEAT" subtitle
    -   Form card (`_kSurface` background, rounded border): Identifier field, Password field with visibility toggle
    -   Inline `Form` validation: empty identifier → "Please enter your email or mobile number."; empty password → "Please enter your password."
    -   Error banner: shown for `ApiException` (including `AccountForbiddenException`) with server message; red-tinted border and icon
    -   Submit button shows `CircularProgressIndicator` while `_submitting`; button disabled during in-flight request
    -   "Don't have an account? Register" link fires `onRegisterPressed` callback
-   `mobile/lib/features/auth/screens/register_screen.dart` — `RegisterScreen` stateful widget:
    -   Callbacks: `onRegisterSuccess(UserProfile)`, `onLoginPressed` — no `Navigator` calls; parent decides navigation
    -   AppBar "Create Account" with back `IconButton` that fires `onLoginPressed`
    -   Fields: Full Name (required), Email (optional), Mobile (optional), Password with visibility toggle
    -   Inline `Form` validation: empty full name → "Please enter your full name."; empty password → "Please enter a password."
    -   Blank optional fields (email, mobile) → `null` sent to `AuthService.register` (key omitted from request body)
    -   Error banner for `ApiException` 400 (validation) and 409 (conflict)
    -   "Already have an account? Log in" link fires `onLoginPressed` callback

**Flutter — new tests**
-   `mobile/test/features/auth/login_screen_test.dart` — 12 widget tests:
    -   Smoke, identifier field rendered, password field rendered, Log In button rendered
    -   Empty identifier → validation message displayed; empty password → validation message displayed
    -   Successful login → `onLoginSuccess` called with correct `UserProfile`
    -   `ApiException` (401) → error banner shown; `AccountForbiddenException` (403) → error banner shown
    -   Loading spinner visible while login in progress (never-resolving fake)
    -   Register link → `onRegisterPressed` fired
    -   Password visibility toggle changes icon (visibility ↔ visibility_off)
-   `mobile/test/features/auth/register_screen_test.dart` — 15 widget tests:
    -   Smoke, four fields rendered, Register button rendered
    -   Empty full name → validation message displayed; empty password → validation message displayed
    -   Successful registration → `onRegisterSuccess` called with correct `UserProfile`
    -   `ApiException` (400) → error banner shown; `ApiException` (409) → error banner shown
    -   Loading spinner visible while registration in progress (never-resolving fake)
    -   Log in link → `onLoginPressed` fired
    -   Password visibility toggle changes icon
    -   Blank optional fields → service called with `email: null`, `mobile: null`

**Results**
-   flutter analyze — no issues ✅
-   flutter test — 164/164 passed (137 prior + 27 new, zero regressions) ✅

------------------------------------------------------------------------

## v2.5.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 4.6 complete — Flutter Payment UI (DepositSheet, WithdrawSheet, WalletScreen action buttons)

### Details

**Flutter — new files**
-   `mobile/lib/features/wallet/widgets/deposit_sheet.dart` — `DepositSheet` modal bottom sheet:
    -   Material 3 dark/gold design (drag handle, icon+title row, subtitle, form, error banner, submit button) matching ProfileScreen / WalletScreen style exactly
    -   Amount field: `TextInputType.numberWithOptions(decimal: true)`; validated required, parseable, > 0, ≤ 1 000 000
    -   Reference field: optional; blank string → `null` (key not sent to service)
    -   Loading spinner replaces button label during submit; button disabled while saving
    -   Error hierarchy: `SessionExpiredException` → "Session expired." banner; `ApiException` → server message banner; catch-all → "Something went wrong." banner
    -   `onSuccess(PaymentResult)` called before `Navigator.pop()` on server confirmation
-   `mobile/lib/features/wallet/widgets/withdraw_sheet.dart` — `WithdrawSheet` modal bottom sheet:
    -   Same structure as DepositSheet with red accent (instead of green)
    -   Shows current balance chip (`currentBalance` constructor parameter) — wallet balance at open time, formatted identically to WalletScreen `_BalanceCard`
    -   Catches `InsufficientBalanceException` (HTTP 422) specifically: shows "Insufficient balance. Please enter a lower amount." banner; session remains active; tokens NOT cleared; button re-enabled for retry

**Flutter — modified files**
-   `mobile/lib/features/wallet/screens/wallet_screen.dart`:
    -   Added `paymentService` (`PaymentService`, required) constructor parameter
    -   Added `_openDepositSheet()` and `_openWithdrawSheet()` private methods on `_WalletScreenState`; both call `showModalBottomSheet(isScrollControlled: true, backgroundColor: Colors.transparent)`; `onSuccess` callback calls `_loadData()` to reload the full wallet state from the server
    -   Added `onDeposit` / `onWithdraw` callbacks to `_WalletView` (stateless widget), passed from `_WalletScreenState`
    -   Added Deposit (green `ElevatedButton.icon`, `Key('deposit_button')`) and Withdraw (red `OutlinedButton.icon`, `Key('withdraw_button')`) side-by-side in a `Row` between the balance card and the TRANSACTION HISTORY section header

**Flutter — modified tests**
-   `mobile/test/features/wallet/wallet_screen_test.dart`:
    -   Added `_FakePaymentService` (extends `PaymentService`, constructor-injected `_FakeApiClient`; overrides deposit/withdraw; never calls platform channels)
    -   Updated `_pump()` — added optional `paymentService` parameter (defaults to `_FakePaymentService()`); all existing tests unchanged
    -   Test 7 assertion updated: `find.text('Deposit')` now uses `findsWidgets` because both the Deposit action button and the deposit transaction tile type label contain the text "Deposit"
    -   Added 4 new tests (11–14): Deposit button visible, Withdraw button visible, tapping Deposit opens DepositSheet, tapping Withdraw opens WithdrawSheet
-   `mobile/test/features/wallet/payment_sheet_test.dart` — NEW FILE, 21 tests:
    -   `_FakePaymentService` (configurable deposit/withdraw response or error), `_CapturingPaymentService` (records call arguments)
    -   DepositSheet (tests 1–10): smoke, fields present, empty/invalid/zero amount validation errors, successful deposit (onSuccess called + PaymentResult fields), amount+reference forwarded, blank reference → null, ApiException banner (sheet stays open), SessionExpiredException banner
    -   WithdrawSheet (tests 11–21): smoke, balance+fields displayed, fractional balance formatting, empty/zero amount validation, successful withdraw (onSuccess called), InsufficientBalanceException inline banner (sheet stays open, session intact), ApiException banner, SessionExpiredException banner, amount+reference forwarded, blank reference → null (separate pump)

**No backend changes — Phase 4.4 endpoints consumed as-is.**

**No new dependencies added.**

**Design decisions**
-   `InsufficientBalanceException` shown as a domain-level inline banner (not a session event); the player adjusts the amount and retries without logging in again.
-   `currentBalance` passed to `WithdrawSheet` from `_WalletScreenState._wallet!.points` at sheet-open time — the most recently loaded balance; reload via `onSuccess` refreshes after completion.
-   Deposit button uses green (`_kGreen = 0xFF4CAF50`) and Withdraw uses red outlined (`_kRed = 0xFFFF4C4C`) — consistent with transaction credit/debit color semantics already established in WalletScreen.
-   Blank reference field sends `null` (not empty string) to `PaymentService`; reference key omitted from HTTP body when null (PaymentService Layer contract, Phase 4.5).

**Verified (Flutter 3.32.0 / Dart 3.8.0)**
-   flutter analyze — no issues ✅
-   flutter test — 137/137 passed (112 prior + 25 new, zero regressions) ✅

------------------------------------------------------------------------

## v2.4.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 4.5 complete — Flutter Payment Service Layer (PaymentService, PaymentResult model, InsufficientBalanceException)

### Details

**Flutter — new files**
-   `mobile/lib/features/wallet/models/payment_result.dart` — immutable `PaymentResult` model; wraps `Wallet` + `WalletTransaction`; `fromJson` factory delegates to existing `Wallet.fromJson` and `WalletTransaction.fromJson`
-   `mobile/lib/features/wallet/services/payment_service.dart` — `PaymentService` with constructor-injected `ApiClient` (no singletons):
    -   `deposit({required double amount, String? reference})` → `Future<PaymentResult>`; POSTs `{amount, ?reference}` to `POST /api/wallet/deposit`; reference key omitted from body when not provided; identical error propagation to `WalletService` and `ProfileService`
    -   `withdraw({required double amount, String? reference})` → `Future<PaymentResult>`; POSTs `{amount, ?reference}` to `POST /api/wallet/withdraw`; catches `ApiException(422)` and remaps to `InsufficientBalanceException`; all other exceptions propagate unchanged
-   `mobile/test/features/wallet/payment_service_test.dart` — 22 unit tests in five groups:
    -   **deposit happy-path** (10): wallet fields, transaction fields, amount in body, reference sent when provided, reference key absent when omitted, token refresh + retry (401 → refresh → retry; new token stored), SessionExpiredException when refresh fails, ApiException(500), network failure, no token stored
    -   **withdraw happy-path** (3): all wallet/transaction fields, body shape with reference, reference key absent when omitted
    -   **withdraw insufficient balance** (3): throws InsufficientBalanceException on 422, is ApiException subclass with statusCode 422, carries server message
    -   **withdraw session/network errors** (4): token refresh + retry, SessionExpiredException, ApiException(500), network failure
    -   **PaymentResult.fromJson** (2): all fields parsed, integer amounts coerced to double

**Flutter — modified files**
-   `mobile/lib/core/errors/api_exception.dart` — added `InsufficientBalanceException extends ApiException`; statusCode 422; default message "Insufficient balance."; tokens NOT cleared on throw; session remains active

**No backend changes** — Phase 4.4 endpoints (POST /api/wallet/deposit, POST /api/wallet/withdraw) consumed as-is.

**No new dependencies added.**

**No new database migration required.**

**Design decisions**
-   `InsufficientBalanceException` mirrors the `WrongCurrentPasswordException` pattern from Phase 3.4: the 422 is a domain rejection, not a session event; ApiClient's normal refresh/retry flow is never triggered because 422 ≠ 401.
-   `PaymentService.withdraw` catches `ApiException` at the service layer and remaps 422 → `InsufficientBalanceException`, keeping HTTP semantics out of the UI layer.
-   `reference` is omitted from the request body (not sent as `null`) when not provided, matching backend validation expectations and keeping the payload minimal.
-   No client-side amount validation — the backend is the single source of truth; 400 errors surface as `ApiException(400)`.

**Docs updated:** `06_API.md` (POST /wallet/deposit, POST /wallet/withdraw endpoints documented), `02_PROJECT_STATUS.md`, `09_CHANGELOG.md`

**Verified (Flutter 3.32.0 / Dart 3.8.0)**
-   flutter analyze — no issues ✅
-   flutter test — 112/112 passed (90 prior + 22 new, zero regressions) ✅

------------------------------------------------------------------------

## v2.3.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 4.4 complete — Backend Payment Foundation (provider-agnostic deposit & withdraw endpoints with atomic PostgreSQL transactions)

### Details

**Backend — modified files**
-   `backend/src/services/wallet.service.ts` — two new exported functions and one new domain error class:
    -   `InsufficientBalanceError` — typed domain error thrown when withdraw amount exceeds balance; avoids leaking DB constraint errors to callers
    -   `depositPoints(userId, amount, reference?)` — atomic credit operation: acquires a `pg.PoolClient`, wraps the entire flow in `BEGIN/COMMIT`: upsert wallet via `INSERT … ON CONFLICT`, insert transaction row with `status='pending'`, `UPDATE wallets SET points += amount, total_deposit += amount`, flip transaction to `status='completed'`; `ROLLBACK` on any error
    -   `withdrawPoints(userId, amount, reference?)` — atomic debit operation: same client pattern plus `SELECT … FOR UPDATE` row-lock after upsert, pre-flight balance check (throws `InsufficientBalanceError` before touching data if balance is insufficient), same pending→completed transaction lifecycle; DB `CHECK (points >= 0)` is the final hard constraint
    -   `PaymentResult` — exported interface `{ wallet: WalletRow; transaction: TransactionRow }` returned by both functions
-   `backend/src/controllers/wallet.controller.ts` — two new exported handler functions:
    -   `deposit(req, res)` — validates `amount` (required, positive finite number, ≤ 1 000 000, rounded to 2 d.p.) and optional `reference` (string, ≤ 255 chars); calls `depositPoints`; returns `{ success, data: { wallet, transaction } }` (200); 500 on unexpected errors
    -   `withdraw(req, res)` — same validation; calls `withdrawPoints`; returns 200 on success, 422 `Insufficient balance.` on `InsufficientBalanceError`, 500 on other errors
-   `backend/src/routes/wallet.ts` — two new authenticated POST routes: `POST /wallet/deposit → deposit`, `POST /wallet/withdraw → withdraw`

**Backend — new files**
-   `backend/tests/phase44_wallet_payment.sh` — 50 integration tests covering: auth protection (4), deposit input validation (5), withdraw input validation (4), deposit happy-path with and without reference (13), withdraw happy-path (9), insufficient balance (3), balance cross-check via GET /wallet (6), history cross-check (4), decimal amount support (2)

**Bug fix (pre-existing, unrelated to Phase 4.4)**
-   `backend/tests/phase31_profile.sh` — changed hardcoded `BASE="http://localhost:5000/api"` to `BASE="${BASE:-http://localhost:5000/api}"` so the script honours the `BASE` environment variable (the same pattern used in all other test scripts)

**No database migration required** — Phase 4.4 uses only the `wallets` and `transactions` tables created in Phase 4.1 (migrations 0004 and 0005).

**No new dependencies.**

**Design decisions**
-   Provider-agnostic by design: neither endpoint knows about any payment gateway. The mobile app (or a future webhook handler) is responsible for verifying that a real-world payment succeeded before calling `POST /wallet/deposit`.
-   `SELECT … FOR UPDATE` prevents concurrent over-draws: two simultaneous withdraw requests for the same wallet will serialize correctly; only one can succeed if the balance covers only one.
-   `Math.round(amount * 100) / 100` normalises the amount to 2 decimal places before it reaches the DB, keeping the NUMERIC(18,2) column exact.
-   `InsufficientBalanceError` is caught at the controller layer and mapped to HTTP 422, keeping the error semantics clear and the service layer free of HTTP knowledge.

**Verified (backend build + integration tests)**
-   `pnpm run build` — clean ✅
-   Phase 4.4 tests — 50/50 passed ✅
-   Phase 4.1 tests — 31/31 passed (zero regressions) ✅
-   Phase 3.6 tests — 21/21 passed (zero regressions) ✅
-   Phase 3.3 tests — 25/25 passed (zero regressions) ✅
-   Phase 3.1 tests — run after port fix: passed (see below) ✅

------------------------------------------------------------------------

## v2.2.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 4.3 complete — Flutter Wallet Screen UI (WalletScreen with balance card, transaction history, and full widget test suite)

### Details

**Flutter — new files**
-   `mobile/lib/features/wallet/screens/wallet_screen.dart` — `WalletScreen` StatefulWidget with constructor-injected `WalletService`; three UI states (loading, error, data) with `AnimatedSwitcher` (280 ms); pull-to-refresh via `RefreshIndicator`; loads wallet and history in parallel with `Future.wait`; identical error propagation and state pattern to `ProfileScreen`
    -   `_BalanceCard` — gradient card with gold border; displays `points` prominently (large, bold), `total_deposit` in green, `total_withdraw` in red; integer amounts displayed without decimals
    -   `_StatColumn` — reusable label + coloured value column used inside the balance card
    -   `_TransactionTile` — coloured circular icon, type label, formatted local date, signed amount (+ for credit, - for debit), `_StatusPill`
    -   `_StatusPill` — colour-coded pill: green (completed), amber (pending), red (failed), grey (reversed); matches `ProfileStatusBadge` visual style
    -   `_EmptyHistoryView` — icon + "No transactions yet" copy shown when `history.transactions` is empty
    -   `_LoadingView` / `_ErrorView` — identical structure to `ProfileScreen` equivalents
-   `mobile/test/features/wallet/wallet_screen_test.dart` — 10 widget tests using fake `WalletService` subclasses (no `FlutterSecureStorage` platform-channel dependencies), covering: smoke render, loading indicator, balance display, zero balance, empty history view, transaction list, deposit tile (+prefix / Pending status), error state, retry flow, pull-to-refresh reload count

**No backend changes** — Phase 4.1 endpoints consumed as-is.

**No new dependencies** — wallet screen uses only existing Flutter SDK widgets and the `WalletService`/models from Phase 4.2.

**No new database migration required.**

**Design decisions**
-   `Future.wait([getWallet(), getHistory()])` loads both data sources in parallel on `initState` and on every pull-to-refresh — one spinner covers both, and any error from either surfaces as the error state.
-   `CustomScrollView` + `SliverFillRemaining` chosen over `SingleChildScrollView` so the empty-history view correctly fills the remaining viewport height while the pull-to-refresh gesture still works on all screen sizes.
-   Dark arcade palette constants (`_kBg`, `_kSurface`, `_kPrimary`, `_kGold`, `_kBorder`, `_kTextSecondary`, `_kGreen`, `_kRed`, `_kAmber`) defined at file scope — consistent with `ProfileScreen` colour tokens.
-   Integer formatting (`v.toInt().toString()` when `v == v.truncateToDouble()`) avoids spurious `.0` suffix on whole-number balances.

**Verified (Flutter 3.32.0 / Dart 3.8.0)**
-   flutter analyze — no issues ✅
-   flutter test — 90/90 passed (80 prior tests + 10 new wallet screen tests, zero regressions) ✅

------------------------------------------------------------------------

## v2.1.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 4.2 complete — Flutter Wallet Service (service layer only, no UI)

### Details

**Flutter — new files**
-   `mobile/lib/features/wallet/models/wallet.dart` — immutable `Wallet` model (`id`, `points`, `totalDeposit`, `totalWithdraw`, `updatedAt`; `fromJson` converts `num` → `double`); `WalletHistory` model (`transactions`, `total`, `limit`, `offset`; `fromJson` unwraps `pagination.count` into `total`)
-   `mobile/lib/features/wallet/models/wallet_transaction.dart` — immutable `WalletTransaction` model (`id`, `type`, `amount`, `status`, `reference?`, `createdAt`; `fromJson` coerces `num` → `double` for amount)
-   `mobile/lib/features/wallet/services/wallet_service.dart` — `WalletService` with constructor-injected `ApiClient`; `getWallet()` calls GET /api/wallet; `getHistory({int limit = 20, int offset = 0})` calls GET /api/wallet/history with limit/offset as query params; identical error propagation (`ApiException`, `SessionExpiredException`, network exceptions) to `ProfileService`
-   `mobile/test/features/wallet/wallet_service_test.dart` — 21 unit tests organised in four groups: `getWallet` (success, non-zero balance, 401 session expiry, token refresh + retry, 500 error, malformed response, network failure), `getHistory` (empty, populated, multi-transaction, pagination params verified via captured request, default params, 401, 500, malformed, network failure), `Wallet.fromJson` (field types, int-to-double coercion), `WalletTransaction.fromJson` (null reference, populated reference, int-to-double coercion)

**No backend changes** — Phase 4.1 endpoints consumed as-is.

**No new dependencies** — wallet service uses the existing `ApiClient`, `TokenStorage`, `ApiException`, and `SessionExpiredException` from the core layer.

**Verified (Flutter 3.32.0 / Dart 3.8.0)**
-   flutter pub get — no errors ✅
-   flutter analyze — no issues ✅
-   flutter test — 80/80 passed (59 prior tests + 21 new wallet tests, zero regressions) ✅

------------------------------------------------------------------------

## v2.0.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 4.1 complete — Wallet Backend Foundation (GET /api/wallet, GET /api/wallet/history)

### Details

**Database — new migrations**
-   `backend/src/db/migrations/0004_create_wallets_table.sql` — wallets table: UUID PK, user_id FK UNIQUE with CASCADE, points/total_deposit/total_withdraw NUMERIC(18,2) DEFAULT 0 CHECK >= 0, updated_at maintained by the existing set_updated_at() trigger
-   `backend/src/db/migrations/0005_create_transactions_table.sql` — transactions table: UUID PK, user_id FK, type CHECK IN (deposit/withdraw/reward/entry_fee/refund), amount NUMERIC(18,2), status CHECK IN (pending/completed/failed/reversed) DEFAULT 'completed', reference TEXT, created_at; compound index on (user_id, created_at DESC) for efficient history queries
-   `backend/src/db/migrations/0006_backfill_wallets_for_existing_users.sql` — INSERT … ON CONFLICT DO NOTHING to create zero-balance wallets for all users registered before Phase 4.1

**Backend — new files**
-   `backend/src/services/wallet.service.ts` — `findWalletByUserId()`, `findOrCreateWallet()` (atomic INSERT … ON CONFLICT DO UPDATE upsert that always returns the row), `getTransactions()` (paginated, newest first)
-   `backend/src/controllers/wallet.controller.ts` — `getWallet()` (auto-creates wallet on first access via findOrCreateWallet); `getWalletHistory()` (parses and clamps limit 1–100 default 20 and offset ≥0 default 0; returns transactions array + pagination envelope)
-   `backend/src/routes/wallet.ts` — GET /wallet and GET /wallet/history, both behind authenticate middleware
-   `backend/tests/phase41_wallet.sh` — 31-assertion integration test suite covering: auth protection on both endpoints, wallet initial state (0 points, all fields present, user_id not exposed), wallet idempotency (same id on repeated calls), empty history for new user, pagination params (custom limit, offset, limit clamped at 100, non-numeric falls back to default, negative offset falls back to 0)

**Backend — modified files**
-   `backend/src/routes/index.ts` — walletRouter imported and mounted

**No Flutter changes** — Flutter wallet service layer is a future phase.

**No new architecture** — follows existing controller/service/route separation.

**Design decisions**
-   `findOrCreateWallet` uses `INSERT … ON CONFLICT (user_id) DO UPDATE SET updated_at = wallets.updated_at RETURNING *` so the row is always returned atomically, safe under concurrent requests, with no separate SELECT needed.
-   NUMERIC columns from pg arrive as strings; controller converts with `parseFloat()` before serialising to JSON so clients receive numbers, not strings.
-   History endpoint silently clamps out-of-range pagination params rather than returning 400, consistent with read-only query patterns where clamping is safer than erroring.
-   Transactions table is append-only (no UPDATE/DELETE in schema or service layer) — financial audit trail is preserved by design.

**Verified (Node.js 20 / Express 5)**
-   Migrations 0004–0006 applied ✅
-   pnpm run build — zero TypeScript errors ✅
-   31/31 Phase 4.1 tests pass ✅
-   35/35 Phase 3.1 tests pass (no regressions) ✅
-   25/25 Phase 3.3 tests pass (no regressions) ✅
-   21/21 Phase 3.6 tests pass (no regressions) ✅

------------------------------------------------------------------------

## v1.9.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 3.6 complete — Backend Avatar Upload Endpoint (PUT /api/profile/avatar)

### Details

**Backend — new files**
-   `backend/src/lib/upload.ts` — multer disk-storage configuration: AVATARS_DIR at `backend/uploads/avatars/`, filename = `<user-id>.<ext>`, fileFilter accepts only `image/jpeg` / `image/png` / `image/webp` (others rejected with coded `INVALID_MIME_TYPE` error), 2 MB size limit; exports `avatarUpload` instance, `AVATARS_DIR` constant, and `MIME_TO_EXT` map used by the controller for stale-file cleanup
-   `backend/tests/phase36_avatar_upload.sh` — 21-assertion integration test suite covering: auth protection (no token, invalid token), validation (no file, disallowed MIME type, file > 2 MB), successful JPEG/PNG/WEBP uploads, GET /profile reflects new avatar URL, static file served at returned URL, second upload replaces first (stale extension cleaned up)
-   `backend/uploads/avatars/.gitkeep` — ensures the uploads directory is tracked in git while binary assets are excluded

**Backend — modified files**
-   `backend/src/app.ts` — added `express.static` for `/uploads` pointing to `backend/uploads/` (resolved relative to bundle output in `dist/`); mounted before the API router
-   `backend/src/controllers/profile.controller.ts` — added `uploadAvatar()` handler: confirms file present, removes stale avatar files with other extensions via `fs.unlink`, constructs public URL from `req.protocol + req.get('host')`, calls `updateProfileById` to persist URL, returns `{ success: true, data: { avatar } }`
-   `backend/src/routes/profile.ts` — added `handleAvatarUpload` wrapper function that runs `avatarUpload.single('avatar')` and converts `MulterError(LIMIT_FILE_SIZE)` → 400 and `INVALID_MIME_TYPE` error → 400 before calling `uploadAvatar`; added `router.put('/profile/avatar', authenticate, handleAvatarUpload, uploadAvatar)`
-   `backend/package.json` — added `multer ^2.2.0` and `@types/multer ^2.2.0`
-   `.gitignore` — added `backend/uploads/avatars/*` / `!backend/uploads/avatars/.gitkeep` to exclude binary uploads from version control

**No Flutter changes** — Flutter service layer is Phase 3.7.

**No database changes** — `avatar TEXT` column already exists in users table from migration 0001.

**Design decisions**
-   Filename strategy `<user-id>.<ext>` ensures one file per user per extension; stale extension cleanup in the controller handles cross-format replacements (e.g. JPEG → PNG) without leaving orphaned files.
-   `AVATARS_DIR` uses `path.resolve(__dirname, '../uploads/avatars')` (one level up from `dist/`) rather than two, because esbuild bundles all source files into `dist/index.mjs`; `import.meta.url` therefore always resolves relative to the bundle output, not the original source path.
-   Multer error handling wrapped in `handleAvatarUpload` in the route file (not the controller) to keep the controller focused on business logic; the route layer owns transport-level concerns.

**Verified (Node.js 20 / Express 5)**
-   pnpm run build — no TypeScript errors ✅
-   21/21 integration tests pass ✅

------------------------------------------------------------------------

## v1.8.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 3.5 complete — Flutter Profile Screen UI (Profile Screen + Edit Profile Sheet + Change Password Sheet)

### Details

**Mobile — new production files**
-   `mobile/lib/features/profile/widgets/profile_avatar.dart` — circular avatar widget with gold-gradient ring and box-shadow; falls back to player-initials monogram when no avatar URL is set
-   `mobile/lib/features/profile/widgets/profile_info_tile.dart` — icon + label + value row used inside the profile info card
-   `mobile/lib/features/profile/widgets/profile_status_badge.dart` — colour-coded pill badge: green (active), amber (suspended), red (banned)
-   `mobile/lib/features/profile/widgets/edit_profile_sheet.dart` — modal bottom sheet; edits fullName / country / avatar URL via `ProfileService.updateProfile`; calls `onSuccess(UserProfile)` callback on successful save so the parent screen updates without a second network call
-   `mobile/lib/features/profile/widgets/change_password_sheet.dart` — modal bottom sheet; calls `ChangePasswordService.changePassword`; maps `WrongCurrentPasswordException` to an inline field validation error so the sheet stays open and the player's session is preserved
-   `mobile/lib/features/profile/screens/profile_screen.dart` — stateful screen with loading / error / data states; `RefreshIndicator` for pull-to-refresh; `AnimatedSwitcher` transitions between states; Edit Profile and Change Password action buttons open their respective sheets; receives updated `UserProfile` from the Edit Profile sheet to refresh the display without a second network round-trip

**Mobile — new test file**
-   `mobile/test/features/profile/profile_screen_test.dart` — 10 widget tests using fake service subclasses (no platform-channel dependencies) covering: smoke render, loading indicator, profile data display, error state, retry flow, Edit Profile sheet opens, Change Password sheet opens, pull-to-refresh, edit sheet saves and updates screen, wrong-password inline error keeps sheet open

**Mobile — modified files**
-   `mobile/lib/features/profile/screens/profile_screen.dart` — `_PrimaryButton` and `_SecondaryButton` private widgets accept `super.key`; Edit Profile and Change Password buttons tagged with `Key('edit_profile_button')` and `Key('change_password_button')` for reliable widget-test targeting

**No backend changes** — Phase 3.3 endpoints (GET /api/profile, PUT /api/profile, PUT /api/profile/password) reused as-is.

**No database changes** — no new migrations.

**Design decisions**
-   `WrongCurrentPasswordException` mapped to inline field error (not session expiry): consistent with Phase 3.4 service-layer design; the player stays logged in and can correct the mistake without re-authentication.
-   Widget tests use fake `ProfileService` / `ChangePasswordService` subclasses that override service methods directly, eliminating MethodChannel (FlutterSecureStorage) timing dependencies that prevent reliable async flushing in `testWidgets`.
-   Buttons are tagged with widget keys (`Key('edit_profile_button')`, `Key('change_password_button')`) because `OutlinedButton.icon()` returns `_OutlinedButtonWithIcon` (internal Flutter type) which does not always match `find.widgetWithText(OutlinedButton, ...)` across Flutter versions.

**Verified (Flutter 3.32.0)**
-   flutter analyze — no issues ✅
-   10/10 new widget tests pass ✅
-   59/59 total Flutter tests pass (no regressions) ✅

------------------------------------------------------------------------

## v1.7.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 3.4 complete — Flutter Change Password Service Layer

### Details

**Mobile — new files**
-   `mobile/lib/features/profile/services/change_password_service.dart` — `ChangePasswordService` with `changePassword(currentPassword, newPassword)` → `Future<void>`; wraps PUT /api/profile/password; maps "Current password is incorrect" 401 to `WrongCurrentPasswordException`; passes `domainRejectionPattern` to prevent wrong-password 401s from clearing tokens
-   `mobile/test/features/profile/change_password_service_test.dart` — 11 unit tests covering: successful change, correct request body shape, token refresh + retry, wrong password (WrongCurrentPasswordException), validation failure (ApiException 400), server error (ApiException 500), no token (SessionExpiredException), both tokens expired (SessionExpiredException), network timeout

**Mobile — modified files**
-   `mobile/lib/core/errors/api_exception.dart` — added `WrongCurrentPasswordException extends ApiException`; thrown when the backend rejects the current password with 401; tokens are NOT cleared; the session remains active
-   `mobile/lib/core/network/api_client.dart` — added optional `domainRejectionPattern` parameter to `authenticatedRequest`; when a 401 body message contains the pattern the response is decoded as `ApiException` directly (no refresh, no token clearing); the JSON parsing is isolated in its own try-catch so the resulting `ApiException` propagates correctly; fully backward-compatible — all existing callers pass `null` implicitly and are unaffected

**No backend changes** — Phase 3.3 endpoint (PUT /api/profile/password) reused as-is.

**No database changes** — no new migrations.

**Design decision: domainRejectionPattern vs bypassRefreshOn401**
An earlier approach using `bypassRefreshOn401: true` was rejected because it blindly blocked token refresh for ALL 401s on the endpoint, including genuine token-expiry 401s. The `domainRejectionPattern` approach inspects the 401 response body: if the message matches the pattern it is a domain rejection; if not, the normal refresh/retry flow proceeds. This correctly handles both "wrong password" (no refresh, no token clearing) and "expired access token" (refresh → retry) on the same endpoint.

**Verified (Flutter 3.32.0)**
-   flutter analyze — no issues ✅
-   11/11 new tests pass ✅
-   49/49 total Flutter tests pass (no regressions in ApiClient, TokenStorage, AuthService, ProfileService, or widget tests) ✅

------------------------------------------------------------------------

## v1.6.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 3.3 complete — Change Password endpoint (PUT /api/profile/password)

### Details

**Backend — new files**
-   `backend/tests/phase33_change_password.sh` — 25-assertion integration test suite covering all validation paths, wrong-password rejection, auth protection, successful change, and post-change verification (new password accepted, old password rejected, old refresh token revoked)

**Backend — modified files**
-   `backend/src/services/user.service.ts` — added `updatePasswordById(id, newPasswordHash)`: issues `UPDATE users SET password_hash = $1 WHERE id = $2`, returns boolean indicating whether a row was updated
-   `backend/src/controllers/profile.controller.ts` — added `changePassword()` handler: extracts and validates fields, verifies current password via `bcrypt.compare`, hashes new password (cost 12), calls `updatePasswordById`, revokes all refresh tokens via `deleteRefreshTokensByUser`
-   `backend/src/routes/profile.ts` — added `router.put('/profile/password', authenticate, changePassword)`

**No Flutter changes** — Flutter service layer is Phase 3.4.

**No database changes** — `password_hash TEXT` column already exists in the users table (migration 0001).

**Verified flows (25/25 integration tests pass)**
-   PUT /profile/password empty body → 400 with errors array ✅
-   PUT /profile/password missing current_password → 400, error field = current_password ✅
-   PUT /profile/password missing new_password → 400, error field = new_password ✅
-   PUT /profile/password new_password < 8 chars → 400 ✅
-   PUT /profile/password new_password no letter → 400 ✅
-   PUT /profile/password new_password no digit → 400 ✅
-   PUT /profile/password new_password same as current → 400 ✅
-   PUT /profile/password wrong current_password → 401 "Current password is incorrect." ✅
-   PUT /profile/password no token → 401 ✅
-   PUT /profile/password invalid token → 401 ✅
-   PUT /profile/password valid change → 200, success + message ✅
-   Login with new password → 200 ✅
-   Login with old password → 401 ✅
-   Old refresh token after change → 401 (revoked) ✅

------------------------------------------------------------------------

## v1.5.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 3.2 complete — Flutter Profile Service Layer (getProfile, updateProfile)

### Details

**Flutter — modified files**
-   `mobile/lib/features/auth/models/user_profile.dart` — extended with optional `updatedAt` field (`updated_at` key); present on GET /profile and PUT /profile responses, null for auth responses; existing `fromJson` factory updated to parse it; no breaking changes to existing call sites

**Flutter — new files**
-   `mobile/lib/features/profile/services/profile_service.dart` — `ProfileService` with two methods:
    -   `getProfile()` — calls GET /api/profile, returns `UserProfile` (including `updatedAt`)
    -   `updateProfile({String? fullName, Object? country, Object? avatar})` — calls PUT /api/profile; partial update (only provided fields are sent); `country` and `avatar` accept explicit `null` to clear; throws `ArgumentError` if no fields are provided
    -   Uses private `_Absent` sentinel to distinguish "field not provided" from "explicit null" without boolean flags
-   `mobile/test/features/profile/profile_service_test.dart` — 15 unit tests covering:
    -   `getProfile` success (all fields including `updatedAt`) ✅
    -   `getProfile` 401 → `SessionExpiredException` ✅
    -   `getProfile` 500 → `ApiException` ✅
    -   Automatic token refresh after expired access token (401 → refresh → retry) ✅
    -   Network timeout / offline → throws `Exception` ✅
    -   `updateProfile` full_name update ✅
    -   `updateProfile` country update ✅
    -   `updateProfile` avatar URL update ✅
    -   `updateProfile` avatar cleared by passing null ✅
    -   `updateProfile` country cleared by passing null ✅
    -   `updateProfile` 400 validation error → `ApiException` ✅
    -   `updateProfile` 401 with failed refresh → `SessionExpiredException` ✅
    -   `updateProfile` no fields → `ArgumentError` ✅
    -   `UserProfile.fromJson` all fields parsed correctly including `updatedAt` ✅
    -   `UserProfile.fromJson` nullable fields without cast error ✅

**No backend changes** — Phase 3.1 backend is complete and untouched.

**No database changes** — no new migration required.

------------------------------------------------------------------------

## v1.4.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 3.1 complete — Player Profile Foundation (GET /profile, PUT /profile)

### Details

**Backend — new files**
-   `backend/src/services/profile.service.ts` — findProfileById, updateProfileById (dynamic SET clause, updated_at maintained by DB trigger)
-   `backend/src/controllers/profile.controller.ts` — getProfile, updateProfile (validation: empty body, full_name 2–120 chars, country ≤100 chars, avatar http/https URL or null)
-   `backend/src/routes/profile.ts` — GET /profile and PUT /profile, both behind authenticate middleware
-   `backend/tests/phase31_profile.sh` — 35-assertion test suite covering happy paths, field updates, null-clears, and all validation error cases

**Backend — modified files**
-   `backend/src/routes/index.ts` — mounts profileRouter at root (alongside existing auth/password-reset routers)

**Database**
-   No new migration required — all required columns (full_name, country, avatar, player_id, etc.) already exist in users table from migration 0001
-   Applied all 3 existing migrations (0001–0003) to Replit's built-in PostgreSQL for this environment

**Verified flows (curl + test suite — 35/35 pass)**
-   GET /profile with valid token → 200, profile object without password_hash ✅
-   GET /profile with no token → 401 ✅
-   GET /profile with invalid token → 401 ✅
-   PUT /profile full_name update → 200, GET reflects change ✅
-   PUT /profile country update → 200 ✅
-   PUT /profile avatar URL update → 200 ✅
-   PUT /profile avatar null (clear) → 200, avatar=null ✅
-   PUT /profile country null (clear) → 200, country=null ✅
-   PUT /profile empty body → 400 with errors array ✅
-   PUT /profile full_name < 2 chars → 400 ✅
-   PUT /profile invalid avatar URL → 400, error field = avatar ✅
-   PUT /profile no token → 401 ✅
-   GET /profile final state confirms all updates persisted ✅

------------------------------------------------------------------------

## v1.3.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 2.5.1 complete — Password Reset module (backend + Flutter service layer) verified end-to-end

### Details

**Database**
-   Applied migration 0003_create_password_reset_otps_table.sql — table live with indexes and FK cascade

**Backend — new files**
-   `backend/src/lib/otp.ts` — cryptographically random 6-digit OTP, SHA-256 hash, constant-time comparison
-   `backend/src/lib/email.ts` — Nodemailer SMTP; skips silently when SMTP env vars unset, warns at startup
-   `backend/src/services/password_reset.service.ts` — countRecentOtpRequests, createOtp, incrementLatestOtpAttempt, findOtpById, applyPasswordReset (transactional), deleteExpiredOtps
-   `backend/src/controllers/password_reset.controller.ts` — requestPasswordReset, verifyPasswordResetOtp, confirmPasswordReset
-   `backend/src/routes/password_reset.ts` — mounts three routes under /auth/password-reset/

**Backend — modified files**
-   `backend/src/config/env.ts` — JWT_PASSWORD_RESET_SECRET (required, throws), SMTP_* vars (optional, warns)
-   `backend/src/lib/jwt.ts` — PasswordResetTokenPayload, signPasswordResetToken, verifyPasswordResetToken (JWT_PASSWORD_RESET_SECRET)
-   `backend/src/routes/index.ts` — mounts passwordResetRouter at /auth
-   `backend/src/index.ts` — hourly setInterval for deleteExpiredOtps() with .unref()

**Flutter**
-   `mobile/lib/features/auth/services/password_reset_service.dart` — requestOtp, verifyOtp, confirmReset
-   `mobile/lib/core/errors/api_exception.dart` — OtpExpiredException subclass added

**Secrets**
-   JWT_PASSWORD_RESET_SECRET added to Replit secrets

**Verified flows (curl)**
-   Request OTP → confirm DB row created ✅
-   Wrong OTP → 400 "OTP is incorrect" ✅
-   Correct OTP → reset token issued with sub + otp_id payload ✅
-   Confirm with reset token → password updated, OTP marked used, all refresh tokens deleted ✅
-   Login with new password → succeeds ✅
-   Login with old password → rejected ✅
-   Old refresh token → rejected ✅
-   Reset token replay → "Reset session is no longer valid" ✅
-   Rate limit (3 OTPs/hour) → 429 on 4th request ✅

------------------------------------------------------------------------

## v1.2.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 2.2–2.5 verified end-to-end on Replit — Authentication Module complete

### Details

**Database (Replit environment)**
-   Applied migration 0001_create_users_table.sql — users table live with all triggers and indexes
-   Applied migration 0002_create_refresh_tokens_table.sql — refresh_tokens table live
-   schema_migrations table tracking applied migrations

**End-to-End Verification (Replit)**
-   POST /api/auth/register — new user created, auto player_id (LUD-XXXXXX) generated ✅
-   POST /api/auth/login — access + refresh tokens returned, profile included ✅
-   POST /api/auth/refresh — new access token issued from valid refresh token ✅
-   POST /api/auth/logout — refresh token revoked on server ✅
-   Post-logout refresh attempt — correctly rejected with "Invalid or revoked refresh token." ✅

### Notes

Google Sign In and Country Detection deferred to future phases.
UI screens (login, register) are Phase 2.6 — pending owner approval to begin.

------------------------------------------------------------------------

## v1.1.0

### Date

2026-07-15

### Author

Replit Agent

### Summary

Phase 2.1 — Users Table (Database Foundation)

### Details

-   Added `users` table: id (UUID v4), player_id (LUD-XXXXXX, auto-generated), full_name, email, mobile, password_hash, google_id, country, avatar, is_verified, status, last_login_at, created_at, updated_at
-   Added SQL migration `backend/src/db/migrations/0001_create_users_table.sql`
-   Added migration runner `backend/src/db/migrate.ts` (`pnpm --filter @workspace/backend run migrate`)
-   Added partial unique indexes on email, mobile, google_id; indexes on status and created_at
-   Added trigger to auto-generate `player_id` on insert
-   Added trigger to auto-update `updated_at` on update
-   Verified migration runs successfully against PostgreSQL

### Notes

No authentication logic (register/login/JWT) or Flutter changes included — deferred to Phase 2.2.

------------------------------------------------------------------------

## v1.0.0

### Date

2026-07-14

### Author

Replit Agent + ChatGPT

### Summary

Project Foundation Completed

### Details

-   Initial Flutter project structure
-   Initial Backend structure
-   Express server
-   PostgreSQL configuration
-   Socket.IO foundation
-   GitHub repository connected
-   Documentation started

------------------------------------------------------------------------

## Future Entries

### Template

Version:

Date:

Author:

Summary:

Changes:

-   Added
-   Updated
-   Fixed
-   Removed

Notes:

------------------------------------------------------------------------

# Rules

-   Update this file after every completed feature.
-   Never remove old entries.
-   Add newest entries at the top.
-   Keep version numbers consistent.
-   Mention breaking changes clearly.

------------------------------------------------------------------------

# Example

## v1.1.0

Date: YYYY-MM-DD

Author: Developer / AI

Summary: Authentication System

Changes:

-   Added login
-   Added register
-   Added JWT
-   Added password reset

Notes:

Ready for Phase 3.
