/**
 * Socket.IO game lobby handlers — Phase 5.4 / 5.5.
 *
 * Responsibilities:
 *  - join_room event: verify the player is a match participant, join the
 *    Socket.IO room, track readiness, and emit room_ready when both players
 *    have joined.
 *  - game_start: 2.5 s after room_ready, determine first turn, update match
 *    status to in_progress, and emit game_start to both players (Phase 5.5).
 *  - leave_room event: leave the room, notify the opponent.
 *  - disconnect: clean up room tracking for disconnected sockets.
 *
 * The game lobby phase bridges matchmaking (Phase 5.1–5.3) and gameplay
 * (Phase 6).  Both matched players must emit join_room before the server
 * emits room_ready to either of them.
 */

import type { Server as SocketIOServer, Socket } from "socket.io";
import { pool } from "../db/index.js";
import { logger } from "../lib/logger.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface SocketUserData {
  id: string;
  player_id: string;
  fullName: string;
  avatar: string | null;
}

type AuthSocket = Socket & { data: { user: SocketUserData } };

// ---------------------------------------------------------------------------
// In-memory room readiness tracker
// matchId → Set of socketIds that have successfully joined the room
// ---------------------------------------------------------------------------

const roomJoinedSockets = new Map<string, Set<string>>();

// ---------------------------------------------------------------------------
// Phase 5.5 — Game start
// ---------------------------------------------------------------------------

/**
 * Called ~2.5 seconds after room_ready.
 *
 * 1. Reads both players' colours from match_players.
 * 2. Randomly selects the first turn.
 * 3. Updates matches.status = 'in_progress' and matches.started_at = NOW().
 * 4. Emits game_start { matchId, firstTurn } to all sockets in the room.
 */
async function handleGameStart(
  io: SocketIOServer,
  matchId: string,
): Promise<void> {
  if (!pool) {
    logger.warn({ matchId }, "Game start: database unavailable.");
    return;
  }

  try {
    // Read both players' colours
    const playersResult = await pool.query<{ color: string }>(
      "SELECT color FROM match_players WHERE match_id = $1",
      [matchId],
    );

    if (playersResult.rows.length < 2) {
      logger.warn({ matchId, found: playersResult.rows.length },
        "Game start: fewer than 2 players found in match_players.");
      return;
    }

    // Randomly select first turn
    const randomIndex = Math.floor(Math.random() * playersResult.rows.length);
    const firstTurn   = playersResult.rows[randomIndex]!.color;

    // Update match status
    await pool.query(
      "UPDATE matches SET status = 'in_progress', started_at = NOW() WHERE id = $1",
      [matchId],
    );

    // Emit game_start to both players in the room
    io.to(matchId).emit("game_start", { matchId, firstTurn });

    logger.info({ matchId, firstTurn }, "Game lobby: game_start emitted.");
  } catch (err) {
    logger.error({ err, matchId }, "Game lobby: handleGameStart threw.");
  }
}

// ---------------------------------------------------------------------------
// Event handlers
// ---------------------------------------------------------------------------

/**
 * Handle the `join_room` event emitted by the client.
 *
 * Verifies the player is in the match, joins the Socket.IO room, and emits
 * `room_ready` to all participants once both players have joined.
 * After room_ready, schedules `game_start` for 2.5 seconds later (Phase 5.5).
 */
async function handleJoinRoom(
  socket: AuthSocket,
  io: SocketIOServer,
  data: unknown,
): Promise<void> {
  const user = socket.data.user;
  const matchId = (data as Record<string, unknown> | null)?.["matchId"];

  if (!matchId || typeof matchId !== "string") {
    socket.emit("error", { message: "join_room requires matchId." });
    return;
  }

  if (!pool) {
    socket.emit("error", { message: "Database unavailable." });
    return;
  }

  // Verify the authenticated player is a participant in the match
  const result = await pool.query<{ id: string }>(
    "SELECT id FROM match_players WHERE match_id = $1 AND user_id = $2",
    [matchId, user.id],
  );

  if (result.rows.length === 0) {
    socket.emit("error", { message: "You are not a player in this match." });
    return;
  }

  // Join the Socket.IO room
  await socket.join(matchId);

  // Track which sockets have joined this room
  if (!roomJoinedSockets.has(matchId)) {
    roomJoinedSockets.set(matchId, new Set<string>());
  }
  roomJoinedSockets.get(matchId)!.add(socket.id);

  const playerCount = roomJoinedSockets.get(matchId)!.size;

  socket.emit("room_joined", { matchId, playerCount });

  logger.info(
    { userId: user.id, matchId, playerCount },
    "Game lobby: player joined room.",
  );

  // Once both players are in, emit room_ready then schedule game_start
  if (playerCount >= 2) {
    io.to(matchId).emit("room_ready", { matchId });
    roomJoinedSockets.delete(matchId);
    logger.info({ matchId }, "Game lobby: both players joined — room ready.");

    // Phase 5.5: update match status and notify clients after 2.5 s
    const gameStartTimer = setTimeout(() => {
      handleGameStart(io, matchId).catch((err) => {
        logger.error({ err, matchId }, "Game lobby: game_start timer threw.");
      });
    }, 2500);

    // Allow the process to exit cleanly even if the timer is pending
    gameStartTimer.unref();
  }
}

/**
 * Handle the `leave_room` event emitted by the client.
 *
 * Removes the player from the Socket.IO room and notifies the opponent.
 * Idempotent — safe to call when not in the room.
 */
function handleLeaveRoom(socket: AuthSocket, data: unknown): void {
  const user = socket.data.user;
  const matchId = (data as Record<string, unknown> | null)?.["matchId"];

  if (!matchId || typeof matchId !== "string") return;

  socket.leave(matchId);

  const sockets = roomJoinedSockets.get(matchId);
  if (sockets) {
    sockets.delete(socket.id);
    if (sockets.size === 0) roomJoinedSockets.delete(matchId);
  }

  socket.emit("room_left", { matchId });
  // Notify the remaining player (if any) that their opponent left
  socket.to(matchId).emit("opponent_left", { matchId });

  logger.info({ userId: user.id, matchId }, "Game lobby: player left room.");
}

/**
 * Clean up room tracking when a socket disconnects.
 *
 * Notifies any remaining players in the room that the opponent left.
 */
function handleDisconnectForLobby(socket: AuthSocket): void {
  for (const [matchId, sockets] of roomJoinedSockets.entries()) {
    if (sockets.has(socket.id)) {
      sockets.delete(socket.id);
      // Notify the other player
      socket.to(matchId).emit("opponent_left", { matchId });
      if (sockets.size === 0) roomJoinedSockets.delete(matchId);

      logger.info(
        { socketId: socket.id, matchId },
        "Game lobby: disconnected socket removed from room.",
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Public setup function
// ---------------------------------------------------------------------------

/**
 * Register the game lobby event handlers on the Socket.IO server.
 * Must be called once during server startup, inside `initSocket`.
 *
 * @param io - The already-created Socket.IO server instance.
 */
export function setupGameLobbyHandlers(io: SocketIOServer): void {
  io.on("connection", (socket) => {
    const authSocket = socket as AuthSocket;

    socket.on("join_room", (data) => {
      handleJoinRoom(authSocket, io, data).catch((err) => {
        logger.error({ err, socketId: socket.id }, "join_room handler threw.");
      });
    });

    socket.on("leave_room", (data) => {
      handleLeaveRoom(authSocket, data);
    });

    socket.on("disconnect", () => {
      handleDisconnectForLobby(authSocket);
    });
  });
}
