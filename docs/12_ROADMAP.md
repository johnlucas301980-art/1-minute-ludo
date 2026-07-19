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

-   Ludo board
-   Dice
-   Pawn movement
-   Turn system
-   Timer
-   Winner detection

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
