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

## find_match

Client requests an online match.

## match_found

Server returns matched room.

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
