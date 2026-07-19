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

Move selected pawn.

## pawn_moved

Broadcast pawn movement.

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
