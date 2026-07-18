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

Join an existing room.

## leave_room

Leave current room.

------------------------------------------------------------------------

# Game Events

## game_start

Match begins.

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

## game_over

Match finished.

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
