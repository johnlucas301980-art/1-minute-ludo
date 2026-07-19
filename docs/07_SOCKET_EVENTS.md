# 07_SOCKET_EVENTS.md

# SOCKET.IO EVENT SPECIFICATION

## Connection

### connect

Triggered when client connects.

### disconnect

Triggered when client disconnects.

### reconnect

Triggered after reconnect.

------------------------------------------------------------------------

# Matchmaking

## Authentication (Phase 5.1)

All Socket.IO connections require a valid JWT access token passed in the
handshake auth object: `{ auth: { token: "<access_token>" } }`.
Unauthenticated connections receive a `connect_error` and are rejected.

## find_match

Client requests an online random match (Phase 5.1).

Direction: Client → Server

Behaviour:
-   If no opponent is waiting, the player is added to the in-memory queue
    and receives `queue_joined`.
-   If an opponent is already waiting, both players are matched immediately:
    the match is created in the database and both receive `match_found`.
-   If the player is already queued (e.g. reconnect), their socketId is
    updated and `queue_joined` is re-emitted.

## queue_joined

Server acknowledges that the player entered the matchmaking queue (Phase 5.1).

Direction: Server → Client

Payload:
-   queueSize — total number of players currently waiting

## leave_queue

Client leaves the matchmaking queue (Phase 5.1).

Direction: Client → Server

Behaviour: removes the player from the queue (idempotent — safe to call
when not queued). Server emits `queue_left` in response.

## queue_left

Server acknowledges that the player left the queue (Phase 5.1).

Direction: Server → Client

Payload:
-   success — always true

## match_found

Server notifies both matched players that a match has been created (Phase 5.1).

Direction: Server → Client (emitted to both players)

Payload:
-   matchId  — UUID of the newly created match row
-   roomCode — 6-character alphanumeric room code
-   color    — assigned board color for the receiving player
               (one of: red, blue, green, yellow)
-   opponent — object: { playerId, fullName, avatar }

## join_room

Join an existing game room (Phase 5.4).

Direction: Client → Server

Payload:
-   matchId — UUID of the match to join

Behaviour:
-   Verifies the authenticated player is a participant in the match.
-   Joins the Socket.IO room identified by matchId.
-   Emits `room_joined` to the joining player.
-   When both matched players have joined, emits `room_ready` to all players
    in the room.

## room_joined

Server acknowledges that the player joined the game room (Phase 5.4).

Direction: Server → Client

Payload:
-   matchId     — UUID of the match
-   playerCount — number of players currently in the room (1 or 2)

## room_ready

Server notifies both players that the game room is fully populated (Phase 5.4).

Direction: Server → Client (emitted to all players in the room)

Payload:
-   matchId — UUID of the match

## leave_room

Leave the current game room (Phase 5.4).

Direction: Client → Server

Payload:
-   matchId — UUID of the match to leave

Behaviour:
-   Removes the player from the Socket.IO room.
-   Emits `room_left` to the leaving player.
-   Emits `opponent_left` to the remaining player (if any).

## room_left

Server acknowledges that the player left the game room (Phase 5.4).

Direction: Server → Client

Payload:
-   matchId — UUID of the match

## opponent_left

Server notifies the remaining player that their opponent left (Phase 5.4).

Direction: Server → Client

Payload:
-   matchId — UUID of the match

------------------------------------------------------------------------

# Game Events

## game_start

Server notifies both players that the match is now `in_progress` and which
colour goes first (Phase 5.5).

Direction: Server → Client (emitted to all players in the room)

Timing: emitted ~2.5 seconds after `room_ready`, once the server has:

1.  Selected the first turn (random colour from `match_players`).
2.  Updated `matches.status = 'in_progress'` and `matches.started_at = NOW()`.

Payload:

-   matchId   — UUID of the match that has started
-   firstTurn — board colour of the player who goes first
               (one of: red, blue, green, yellow)

## player_ready

Player confirms readiness.

## roll_dice

Player rolls dice.

## dice_result

Server broadcasts dice result.

## move_pawn

Move selected pawn (Phase 6.2).

## pawn_moved

Broadcast pawn movement (Phase 6.2).

## turn_changed

Next player's turn.

## timer_update

Remaining time update.

## player_finished

Player completed game.

## forfeit

Client surrenders the current match (Phase 5.6).

Direction: Client → Server

Payload:
-   matchId — UUID of the in_progress match to forfeit

Behaviour:
-   Verifies the caller is a participant in the match.
-   Guards: match must be `in_progress` (idempotent — safe for double-taps).
-   Sets `matches.status = 'finished'`, `matches.winner_id = opponent`,
    `matches.finished_at = NOW()`.
-   Emits `game_over` to all players in the room.
-   Any player who disconnects during an in_progress match triggers the same
    logic automatically (reason: `'disconnect'`).

## game_over

Server notifies both players that the match has finished (Phase 5.6).

Direction: Server → Client (emitted to all players in the room)

Payload:
-   matchId  — UUID of the finished match
-   winnerId — UUID of the winning user
-   reason   — why the match ended: `'forfeit'` | `'disconnect'`
              (`'completed'` will be added in Phase 6 for normal gameplay)

## winner_declared

Winner information broadcast.

------------------------------------------------------------------------

# Friend Match

## create_room

Create friend room.

## room_created

Room code returned.

## room_joined

Friend joined.

## room_closed

Room closed.

------------------------------------------------------------------------

------------------------------------------------------------------------

# Gameplay (Phase 6)

## roll_dice

Client requests a dice roll for their turn (Phase 6.1).

Direction: Client → Server

Payload:
-   matchId — UUID of the active match

Behaviour:
-   Validates that the match is in_progress, the calling player's turn is
    active, and the current phase is `waiting_roll`.
-   Rolls the dice server-side (1–6). Clients never supply the dice value.
-   Computes valid moves for all 4 of the rolling player's pawns.
-   Emits `dice_rolled` to all players in the room.
-   If no valid moves exist, immediately passes the turn and emits
    `turn_changed`.

Error conditions (emits `error` event to calling socket):
-   Missing matchId
-   Match not found / not in_progress
-   Calling player is not a participant
-   It is not the calling player's turn
-   Current phase is `waiting_move` (pawn must be moved first)

## dice_rolled

Server broadcasts the dice result to all players in the room (Phase 6.1).

Direction: Server → Client (emitted to all players in the room)

Payload:
-   matchId    — UUID of the match
-   color      — colour of the player who rolled (e.g. "red")
-   value      — dice value (integer 1–6)
-   validMoves — array of valid pawn moves; each entry:
    -   pawnIndex — index of the pawn (0–3)
    -   fromPos   — current position of the pawn
    -   toPos     — position the pawn would reach

Position encoding:
-   0       = yard (home base, not on the board)
-   1–51    = shared track (colour-relative)
-   52–56   = home column (colour-specific, cannot be captured)
-   57      = finished (in the centre)

Notes:
-   `validMoves` is empty when the dice value produces no legal moves
    (e.g. dice < 6 and all pawns are still in the yard). In that case
    `turn_changed` is emitted immediately after `dice_rolled`.

## move_pawn

Move a selected pawn after rolling the dice (Phase 6.2).

Direction: Client → Server

Payload:
-   matchId   — UUID of the match
-   pawnIndex — index of the pawn to move (0–3); must appear in validMoves
                from the most recent dice_rolled event

Behaviour:
-   Validates match in_progress, caller's turn, phase `waiting_move`, and
    pawnIndex in validMoves.
-   Applies the move to the server-side game state.
-   Capture detection: if the pawn lands on a non-safe shared-track square
    (positions 1–51) occupied by an opponent pawn, that pawn is sent back to
    yard (position 0). Safe squares (entry squares + stars) are immune.
-   Emits `pawn_moved` to all players in the room.
-   Win detection: all 4 of the mover's pawns at position 57 (HOME_FINISHED)
    → marks match finished in DB, clears in-memory state, emits
    `game_over { reason: 'completed' }`.
-   Next turn: dice was 6 → same player gets extra turn; any other value →
    turn passes to opponent. Emits `turn_changed` in both cases.

Error conditions (emits `error` event to calling socket):
-   Missing matchId
-   pawnIndex not an integer 0–3
-   Game not found / not in_progress
-   Calling player is not a participant
-   It is not the calling player's turn
-   Current phase is `waiting_roll` (dice must be rolled first)
-   pawnIndex not in validMoves

## pawn_moved

Server broadcasts the result of a pawn move (Phase 6.2).

Direction: Server → Client (emitted to all players in the room)

Payload:
-   matchId            — UUID of the match
-   color              — colour of the player who moved
-   pawnIndex          — index of the moved pawn (0–3)
-   toPosition         — destination position after the move (colour-relative)
-   capturedColor      — (optional) colour of the captured opponent pawn;
                          present only when a capture occurred
-   capturedPawnIndex  — (optional) index of the captured pawn (0–3);
                          present only when a capture occurred

Notes:
-   When capturedColor is present the captured pawn's position is now 0 (yard).
-   After this event, await either `game_over` (mover won) or `turn_changed`
    (to discover whose turn comes next).

## turn_changed

Server notifies all players that the active turn has been resolved (Phase 6.1 / 6.2).

Direction: Server → Client (emitted to all players in the room)

Payload:
-   matchId  — UUID of the match
-   nextTurn — colour of the player who must now roll

Emitted when:
-   The rolling player had no valid moves — turn passes to opponent (Phase 6.1).
-   A pawn was moved after a non-6 dice roll — turn passes to opponent (Phase 6.2).
-   A pawn was moved after a 6 — same player goes again; nextTurn === mover's
    colour (Phase 6.2).

------------------------------------------------------------------------

# Chat

## send_message

## receive_message

------------------------------------------------------------------------

# Presence

## player_online

## player_offline

------------------------------------------------------------------------

# Notifications

## notification

------------------------------------------------------------------------

# Error Events

## error

## unauthorized

------------------------------------------------------------------------

# Event Rules

-   Validate every incoming event.
-   Never trust client state.
-   Backend is the single source of truth.
-   Broadcast only necessary data.
-   Use acknowledgements for critical events.
