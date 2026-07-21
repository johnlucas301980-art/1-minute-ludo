# 12_ROADMAP.md

# PROJECT ROADMAP

## Goal

Deliver a production-ready **1 Minute Ludo** application in small,
testable phases.

------------------------------------------------------------------------

## Phase 1 --- Project Foundation ✅

-   Project structure
-   Flutter foundation
-   Backend foundation
-   PostgreSQL connection
-   Socket.IO setup
-   GitHub repository
-   Documentation

Status: Completed

------------------------------------------------------------------------

## Phase 2 --- Authentication

-   Register
-   Login
-   Google Sign-In
-   JWT
-   Session management
-   Password reset

------------------------------------------------------------------------

## Phase 3 --- Profile & Lobby

-   Home lobby
-   Player profile
-   Avatar
-   Player ID
-   Settings
-   Navigation

------------------------------------------------------------------------

## Phase 4 --- Wallet

-   Balance
-   Transaction history
-   Deposit integration
-   Withdraw request

------------------------------------------------------------------------

## Phase 5 --- Matchmaking

-   Create room
-   Join room
-   Friend match
-   Random match
-   Room code

### Phase 5.6 ✅ Forfeit & Game Termination (2026-07-19)

-   Backend `game_lobby.ts` — `handleForfeit`: verifies participant,
    queries match status (in_progress guard), finds opponent, sets
    `matches.status = 'finished'`, `matches.winner_id`, `matches.finished_at`,
    emits `game_over { matchId, winnerId, reason }` to both players;
    `activeGameBySocketId` Map tracks sockets in active games;
    disconnect during in_progress triggers auto-forfeit (reason: `'disconnect'`)
-   `GameOver` model (`mobile/lib/features/game/models/game_over.dart`)
    — `GameOver(matchId, winnerId, reason)` with `fromJson`, `==`, `hashCode`
-   `GameLobbyService` gains `onGameOver` stream, `forfeit(matchId)` method,
    `_handleGameOver` handler; `game_over` handler registered/cleared in
    `joinRoom`, `leaveRoom`, `dispose`
-   `GameScreen` upgraded to `StatefulWidget`: subscribes to `onGameOver`
    stream; forfeit button emits `forfeit` via service and shows loading
    spinner; `_GameOverOverlay` full-screen result overlay (title, subtitle,
    CONTINUE button); `onGameOver(GameOver)` callback lets parent pop the
    navigation stack; `onForfeit` callback replaced by service injection
-   `MainShell._onGameStart` passes `gameLobbyService` and `onGameOver:
    _onGameOver` to `GameScreen`; `_onGameOver` calls
    `Navigator.popUntil(isFirst)`
-   Backend integration test: `backend/tests/phase56_forfeit.mjs` — 5 tests
    (forfeit→game_over both sockets, missing matchId error, non-participant
    error, double-forfeit idempotent, disconnect auto-forfeit)
-   Flutter tests updated/added: `game_screen_test.dart` (25 tests, includes
    forfeit flow, overlay, CONTINUE callback), `game_lobby_service_test.dart`
    (extended: onGameOver stream, forfeit emit, game_over handler cleanup),
    `main_shell_test.dart` (extended: game_over overlay dismiss pops to root)

### Phase 5.5 ✅ Game Session Initiation (2026-07-19)

-   Backend `game_lobby.ts` — `handleGameStart` scheduled 2.5 s after
    `room_ready`: reads player colours, randomly selects first turn, updates
    `matches.status = 'in_progress'` and `matches.started_at`, emits
    `game_start { matchId, firstTurn }` to both players
-   `GameStarted` model (`mobile/lib/features/matchmaking/models/game_started.dart`)
-   `GameScreen` placeholder (`mobile/lib/features/game/screens/game_screen.dart`)
    — first-turn banner, match info card, placeholder board, forfeit button;
    stateless; constructor DI; no Navigator calls
-   `GameLobbyService` gains `onGameStart` stream and `_handleGameStart` handler
-   `GameLobbyScreen` gains `onGameStart` callback; transitions to
    `GameScreen` on `game_start` event
-   `MainShell` gains `_onGameStart` method; pushes `GameScreen` on top of
    `GameLobbyScreen`; forfeit button pops to shell root via `popUntil`
-   4 new test files: `game_lobby_service_test.dart` (extended),
    `game_lobby_screen_test.dart` (extended), `game_screen_test.dart`,
    `main_shell_test.dart` (extended)

### Phase 5.4 ✅ Flutter Game Lobby (2026-07-19)

-   Backend `join_room` / `leave_room` socket event handlers with in-memory
    room readiness tracking
-   `RoomReady` model
-   `GameLobbyService` (injectable, constructor DI; requires connected
    `SocketClient`; `joinRoom`, `leaveRoom`, `onRoomReady` stream,
    `onOpponentLeft` stream)
-   `GameLobbyException` typed exception
-   `GameLobbyScreen` — 5 states (joining / waiting / ready / opponentLeft /
    error); `AnimatedSwitcher` 280 ms; leave lobby button; AppBar back button
-   `MatchmakingScreen` PLAY button now calls `onMatchReady(MatchFound)`
    callback instead of resetting to idle
-   `MainShell` gains `gameLobbyService` parameter and `_onMatchReady` handler
    that pushes `GameLobbyScreen` via `Navigator.push`
-   `AuthGate`, `OneLudoApp` updated with `gameLobbyService` parameter
-   35 new tests (16 service + 19 screen); 269/269 total passing

### Phase 5.1 ✅ Matchmaking Backend Foundation (2026-07-18)

-   In-memory matchmaking queue (race-condition safe)
-   Socket.IO JWT auth middleware
-   find_match / leave_queue socket events
-   Match creation (atomic DB transaction, random color assignment)
-   GET /api/match/queue/status (REST, read-only)
-   Database migrations: matches + match_players tables
-   Queue stale-entry cleanup
-   41 integration tests (10 REST + 31 Socket.IO)

------------------------------------------------------------------------

## Phase 6 --- Gameplay

### Phase 6.1 ✅ Ludo Game State Engine + roll_dice (2026-07-19)

-   `backend/src/socket/game_engine.ts` — in-memory `LudoGameState`,
    `gameStateMap`, `createGameState`, `clearGameState`, `handleRollDice`;
    emits `dice_rolled` + `turn_changed`; 5 integration tests
-   `backend/src/socket/game_lobby.ts` — wired to `createGameState` on
    `game_start` and `clearGameState` on forfeit/disconnect; `roll_dice`
    event registered

### Phase 6.2 ✅ Move Pawn, Captures & Win Detection (2026-07-19)

-   `handleMovePawn(socket, io, data)` added to `backend/src/socket/game_engine.ts`:
    validates matchId, pawnIndex (0–3), game state exists, participant check,
    correct turn, phase `waiting_move`, pawnIndex in validMoves; applies move;
    capture detection on shared track (positions 1–51), non-safe squares only,
    sends captured pawn back to yard (position 0); emits `pawn_moved
    { matchId, color, pawnIndex, toPosition, capturedColor?, capturedPawnIndex? }`;
    win detection (all 4 pawns at position 57) — updates `matches` table,
    calls `clearGameState`, emits `game_over { reason: 'completed' }`; extra
    turn on dice=6 (same player's colour in `turn_changed`); turn passes to
    opponent on dice≠6
-   `game_lobby.ts` — `move_pawn` event registered; post-move cleanup of
    `activeGameBySocketId` on normal win
-   `backend/tests/phase62_move.mjs` — 8 Socket.IO integration tests:
    pawn_moved shape (both sockets), missing matchId error, wrong phase error,
    wrong turn error, invalid pawnIndex error, non-participant error, extra
    turn after 6, capture detection

### Phase 6.3 ✅ Flutter: Models + GameService (2026-07-19)

-   `mobile/lib/features/game/models/valid_move.dart` — `ValidMove(pawnIndex,
    fromPos, toPos)` with `fromJson`, `==`, `hashCode`, `toString`
-   `mobile/lib/features/game/models/dice_rolled.dart` — `DiceRolled(matchId,
    color, value, validMoves)` with `fromJson` (graceful list parsing), `==`,
    `hashCode`, `toString`
-   `mobile/lib/features/game/models/pawn_moved.dart` — `PawnMoved(matchId,
    color, pawnIndex, toPosition, capturedColor?, capturedPawnIndex?)` with
    `fromJson`, `==`, `hashCode`, `toString`
-   `mobile/lib/features/game/models/turn_changed.dart` — `TurnChanged(matchId,
    nextTurn)` with `fromJson`, `==`, `hashCode`, `toString`
-   `mobile/lib/features/game/services/game_service.dart` — `GameService`
    (constructor DI; `startListening` / `stopListening` / `rollDice` /
    `movePawn` / `dispose`; broadcast streams `onDiceRolled`, `onPawnMoved`,
    `onTurnChanged`; malformed payloads silently dropped)
-   `GameException` typed exception
-   73 new Flutter tests (10 ValidMove + 12 DiceRolled + 13 PawnMoved +
    11 TurnChanged + 27 GameService); `flutter analyze` — no issues

### Phase 6.4 — Flutter: LudoBoardWidget

#### Phase 6.4A ✅ LudoPath Constants (2026-07-19)

-   `mobile/lib/features/game/models/ludo_path.dart` — pure coordinate
    constants mirroring `game_engine.ts` exactly

#### Phase 6.4B ✅ LudoBoardWidget Static Board (2026-07-20)

-   `mobile/lib/features/game/widgets/ludo_board_widget.dart` — static
    15 × 15 board; grid, home yards, home paths, safe-square markers;
    27 widget + data tests

#### Phase 6.4C ✅ LudoBoardWidget Pawn Rendering (2026-07-20)

-   `LudoBoardWidget` gains optional `pawns: Map<String, List<int>>?`
    parameter; `_LudoBoardPainter._drawPawns` renders pawn circles for
    all four position zones (yard, shared track, home column, finished);
    stacking offset layout for multiple pawns on the same cell;
    35 tests total (27 prior + 8 new pawn tests); no interaction yet

### Phase 6.5 ✅ Flutter: Test Suite Finalization (2026-07-20)

-   Full Flutter test suite verified against all Phases 6.1–6.4C
    implementations: 434/434 tests pass, zero regressions
-   `flutter analyze` — no issues ✅
-   `flutter test` — 434/434 passed ✅
    (game models: ValidMove, DiceRolled, PawnMoved, TurnChanged;
    GameService 27 tests; LudoBoardWidget 35 tests; GameScreen 25 tests;
    all prior phase tests confirmed clean)

### Phase 6.7.6 ✅ Backend: Win Completion Integration Test (2026-07-21)

-   `backend/tests/phase676_win_completion.mjs` — 5 integration tests
    covering the full normal-win path: `game_over { reason: 'completed' }`
    to both sockets, `winnerId` matches winner UUID, `roll_dice` rejected
    after win (state cleared), server healthy after win, `matchId`
    consistent on both sockets
-   No backend implementation changes — exercises existing Phase 6.2
    win-detection and Phase 6.1 `clearGameState` paths
-   Backend build clean ✅  `tsc --noEmit` clean ✅

### Phase 6.7.4 ✅ Backend: Pending Game Start Disconnect Protection (2026-07-20)

-   **Race condition fixed:** a player disconnecting in the 2.5-second
    window between `room_ready` and `game_start` now causes the match to
    be cancelled cleanly instead of leaving the remaining player stuck
-   `pendingGameStartByMatchId` Map tracks every match that is between
    `room_ready` and `game_start`, storing both players' `socketId` and
    `userId` alongside the `setTimeout` handle
-   `roomPlayersByMatchId` helper Map accumulates `{socketId, userId}`
    pairs while players are joining; cleared when the pending entry is
    created
-   `handleGameStart` — synchronously checks and removes the pending
    entry before its first `await`; bails out if already removed by the
    disconnect handler (disconnect won the race)
-   `cancelPendingMatch` — new function: sets `matches.status =
    'cancelled'` (idempotent — WHERE guards on `status = 'waiting'`),
    emits `game_over { reason: 'disconnect' }` to the remaining socket
-   `handleDisconnectForLobby` — new block that iterates
    `pendingGameStartByMatchId`; calls `clearTimeout` and
    `cancelPendingMatch` on match; idempotent (second disconnect finds
    no entry)
-   `handleLeaveRoom` — keeps `roomPlayersByMatchId` in sync during the
    pre-ready joining phase
-   All cleanup paths (double disconnect, timer already fired, duplicate
    calls) tested for idempotency — no throws
-   `backend/tests/phase674_pending_disconnect.mjs` — 5 integration
    tests: disconnect in window, no premature game_over on normal start,
    post-game-start disconnect uses active-game path, both-disconnect
    server stability, winnerId equals remaining player's UUID

### Phase 6.7.3 ✅ Flutter: Gameplay Polish & Final Classic Ludo Integration (2026-07-20)

-   `LudoBoardWidget` extended with valid-pawn highlight rings (green)
    and selected-pawn ring (gold); new params `validPawnIndices`,
    `validColor`, `selectedPawnIndex`; `_drawHighlights` painter method
-   `GameScreen` — `_selectedPawnIndex` state; `_onGameOverReceived`
    clears all in-flight gameplay state; `_onMovePawn` sets selection;
    `_onPawnMoved` and `_onTurnChanged` clear selection and dice state
-   Roll button disabled when not my turn, mid-move selection, or
    game over; duplicate rolls prevented by `_rolling` guard (no change)
-   42 game_screen integration tests (was 34); 8 new tests covering
    valid-pawn highlighting, opponent-roll guard, dice reset on turn
    change, capture handling, game-over cleanup

### Phase 6.7.2 ✅ Flutter: LudoBoardWidget + Dice UI wired into GameScreen (2026-07-20)

-   `GameScreen` upgraded to full gameplay UI:
    -   `_PlaceholderBoard` removed; replaced by live `LudoBoardWidget`
        (all pawn positions rendered, updated on every `pawn_moved` event)
    -   `_FirstTurnBanner` replaced by `_TurnBanner` — reflects live
        `_currentTurn` colour, updated on each `turn_changed` event
    -   `_DiceWidget` — dice-face display (value 1–6 or "?" before roll)
        + ROLL button (enabled only on local player's turn before dice
        has been rolled); spinner shown while waiting for `dice_rolled`
    -   `_ValidMovesPanel` — pawn-move buttons (one per entry in
        `validMoves`), shown only when it is the local player's turn and
        the dice has been rolled with at least one legal move; tapping a
        button calls `gameService.movePawn`
    -   `_GameOverOverlay` extended with `'completed'` reason text
    -   Live game state tracked in `_GameScreenState`: `_pawns`,
        `_currentTurn`, `_diceValue`, `_validMoves`, `_rolling`
    -   Stream subscriptions added for `onDiceRolled`, `onPawnMoved`,
        `onTurnChanged` (cancelled in `dispose`)
    -   No `MainShell` / `AuthGate` / `main.dart` changes required
-   `game_screen_test.dart` updated: 34 tests total (was 25)
    -   Tests 12-13 updated: placeholder board → `LudoBoardWidget`
        and dice area assertions
    -   Tests 14a–14c: dice_area, roll_button, initial "?" dice face
    -   Tests 15–26: forfeit + game-over coverage unchanged (renumbered)
    -   Tests 27–34 new: roll-button disabled/enabled state, rollDice
        called on tap, dice value updates after `dice_rolled`, valid-moves
        panel appears and triggers `movePawn`, `turn_changed` updates banner,
        `pawn_moved` does not crash
    -   `_FakeGameService` extended with stream-simulation helpers
        (`simulateDiceRolled`, `simulatePawnMoved`, `simulateTurnChanged`)
        and call-tracking (`rolledDice`, `movedPawnIndices`)
    -   `_pump` return type changed to named record
        `({_FakeGameLobbyService lobby, _FakeGameService game})`

### Phase 6.7.1 ✅ Flutter: GameService wired into GameScreen (2026-07-20)

-   `GameScreen` gains required `gameService: GameService` constructor
    parameter; `initState` calls `startListening()`, `dispose` calls
    `stopListening()`
-   `MainShell` gains `gameService: GameService` parameter; passes it to
    `GameScreen` in `_onGameStart`
-   `AuthGate`, `OneLudoApp`, `main.dart` updated to thread `GameService`
    through the DI chain (socketClient shared with `GameLobbyService`)
-   `game_screen_test.dart` and `main_shell_test.dart` updated with
    `_FakeGameService` subclass; all inline constructors patched
-   Backend build clean ✅  `tsc --noEmit` clean ✅

### Phase 6.6 ✅ Flutter: Final Gameplay Integration (2026-07-20)

-   Documentation finalized for Phases 6.1–6.5:
    `docs/02_PROJECT_STATUS.md`, `docs/09_CHANGELOG.md`,
    `docs/12_ROADMAP.md`, `docs/07_SOCKET_EVENTS.md` updated
-   `game_over` reason `'completed'` documented in socket events spec
    (was deferred from Phase 6.2; now reflects live backend behaviour)
-   Committed and pushed to GitHub (`phase-6.6: final gameplay
    integration`)

------------------------------------------------------------------------

## Phase 7 --- One Minute Mode

-   60-second gameplay
-   Entry points
-   Prize calculation
-   Match completion

------------------------------------------------------------------------

## Phase 8 --- History & Leaderboard

-   Match history
-   Rankings
-   Win/Loss statistics
-   Player achievements

------------------------------------------------------------------------

## Phase 9 --- Notifications & Support

-   Push notifications
-   In-app notifications
-   Help & support

------------------------------------------------------------------------

## Phase 10 --- Admin Panel

-   User management
-   Match monitoring
-   Wallet monitoring
-   Reports
-   Settings

------------------------------------------------------------------------

## Phase 11 --- Testing

-   Unit testing
-   Integration testing
-   Performance optimization
-   Security review
-   Bug fixing

------------------------------------------------------------------------

## Phase 12 --- Production Release

-   Final QA
-   Production deployment
-   Monitoring
-   Backup verification
-   Public release

------------------------------------------------------------------------

# Rules

-   Complete one phase before starting the next.
-   Test every completed feature.
-   Update PROJECT_STATUS.md after each phase.
-   Record every major change in CHANGELOG.md.
-   Push stable work to GitHub regularly.

------------------------------------------------------------------------

# Success Criteria

A secure, scalable, maintainable multiplayer Ludo platform ready for
long-term development.
