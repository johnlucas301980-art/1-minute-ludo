/**
 * Socket.IO game lobby handlers — Phase 5.4 / 5.5 / 5.6.
 *
 * Responsibilities:
 *  - join_room event: verify the player is a match participant, join the
 *    Socket.IO room, track readiness, and emit room_ready when both players
 *    have joined.
 *  - game_start: 2.5 s after room_ready, determine first turn, update match
 *    status to in_progress, and emit game_start to both players (Phase 5.5).
 *  - forfeit: the forfeiting player's opponent becomes the winner; match
 *    status is set to finished and game_over is emitted to both (Phase 5.6).
 *  - leave_room event: leave the room, notify the opponent.
 *  - disconnect: clean up room tracking for disconnected sockets; auto-forfeit
 *    if the disconnect happens during an in_progress match (Phase 5.6).
 *
 * The game lobby phase bridges matchmaking (Phase 5.1–5.3) and gameplay
 * (Phase 6).  Both matched players must emit join_room before the server
 * emits room_ready to either of them.
 */

import type { Server as SocketIOServer, Socket } from "socket.io";
import { pool } from "../db/index.js";
import { logger } from "../lib/logger.js";
import {
  createGameState,
  clearGameState,
  handleRollDice,
  type PawnColor,
} from "./game_engine.js";

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
// Phase 5.6 — Active game socket tracker
// socketId → matchId — lets us auto-forfeit when a socket disconnects
// during an in_progress match.
// ---------------------------------------------------------------------------

const activeGameBySocketId = new Map<string, string>();

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
 * 5. Registers all sockets currently in the room as active game sockets so
 *    disconnect events can trigger auto-forfeit (Phase 5.6).
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
    const playersResult = await pool.query<{ color: string; user_id: string }>(
      "SELECT color, user_id FROM match_players WHERE match_id = $1",
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

    // Phase 6.1: initialise in-memory game state so roll_dice is ready the
    // moment clients receive game_start.
    createGameState(
      matchId,
      [
        {
          userId: playersResult.rows[0]!.user_id,
          color:  playersResult.rows[0]!.color as PawnColor,
        },
        {
          userId: playersResult.rows[1]!.user_id,
          color:  playersResult.rows[1]!.color as PawnColor,
        },
      ],
      firstTurn as PawnColor,
    );

    // Phase 5.6: track all sockets in the room as active game sockets
    const roomSockets = await io.in(matchId).fetchSockets();
    for (const s of roomSockets) {
      activeGameBySocketId.set(s.id, matchId);
    }
  } catch (err) {
    logger.error({ err, matchId }, "Game lobby: handleGameStart threw.");
  }
}

// ---------------------------------------------------------------------------
// Phase 5.6 — Forfeit (shared logic for explicit forfeit and auto-forfeit)
// ---------------------------------------------------------------------------

/**
 * Marks the match as finished with the opponent as winner.
 *
 * Used by both the explicit `forfeit` event (Phase 5.6) and the disconnect
 * auto-forfeit handler.
 *
 * @param io       - Socket.IO server instance.
 * @param matchId  - UUID of the match to terminate.
 * @param forfeitingUserId - UUID of the player who forfeited / disconnected.
 * @param reason   - `'forfeit'` | `'disconnect'`
 */
async function finishMatchByForfeit(
  io: SocketIOServer,
  matchId: string,
  forfeitingUserId: string,
  reason: "forfeit" | "disconnect",
): Promise<void> {
  if (!pool) {
    logger.warn({ matchId }, "Forfeit: database unavailable.");
    return;
  }

  try {
    // Guard: only finish matches that are still in_progress
    const matchResult = await pool.query<{ status: string }>(
      "SELECT status FROM matches WHERE id = $1 LIMIT 1",
      [matchId],
    );

    if (matchResult.rows.length === 0) {
      logger.warn({ matchId }, "Forfeit: match not found.");
      return;
    }

    if (matchResult.rows[0]!.status !== "in_progress") {
      // Already finished — nothing to do (idempotent)
      return;
    }

    // Find the opponent (the other player in this match)
    const opponentResult = await pool.query<{ user_id: string }>(
      `SELECT user_id
         FROM match_players
        WHERE match_id = $1
          AND user_id  != $2
        LIMIT 1`,
      [matchId, forfeitingUserId],
    );

    if (opponentResult.rows.length === 0) {
      logger.warn({ matchId, forfeitingUserId }, "Forfeit: opponent not found.");
      return;
    }

    const winnerId = opponentResult.rows[0]!.user_id;

    // Atomically mark the match as finished
    await pool.query(
      `UPDATE matches
          SET status      = 'finished',
              winner_id   = $1,
              finished_at = NOW()
        WHERE id = $2
          AND status = 'in_progress'`,
      [winnerId, matchId],
    );

    // Clean up active-game tracking for all sockets that were in this match
    for (const [socketId, mid] of activeGameBySocketId.entries()) {
      if (mid === matchId) activeGameBySocketId.delete(socketId);
    }

    // Phase 6.1: clear in-memory game state when the match ends
    clearGameState(matchId);

    // Notify both players
    io.to(matchId).emit("game_over", { matchId, winnerId, reason });

    logger.info(
      { matchId, forfeitingUserId, winnerId, reason },
      "Game: match finished by forfeit.",
    );
  } catch (err) {
    logger.error({ err, matchId, forfeitingUserId }, "Forfeit: threw.");
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
 * Handle the `forfeit` event emitted by the client (Phase 5.6).
 *
 * The forfeiting player's opponent is declared the winner.  The match is
 * set to `finished` in the database and `game_over` is emitted to all
 * players still in the room.
 *
 * Guards:
 *  - matchId must be present in the payload.
 *  - The match must currently be `in_progress` (idempotent for double-clicks).
 *  - The calling player must be a participant.
 */
async function handleForfeit(
  socket: AuthSocket,
  io: SocketIOServer,
  data: unknown,
): Promise<void> {
  const user    = socket.data.user;
  const matchId = (data as Record<string, unknown> | null)?.["matchId"];

  if (!matchId || typeof matchId !== "string") {
    socket.emit("error", { message: "forfeit requires matchId." });
    return;
  }

  if (!pool) {
    socket.emit("error", { message: "Database unavailable." });
    return;
  }

  // Verify the player is a participant before trusting the matchId
  const participantCheck = await pool.query<{ id: string }>(
    "SELECT id FROM match_players WHERE match_id = $1 AND user_id = $2",
    [matchId, user.id],
  );

  if (participantCheck.rows.length === 0) {
    socket.emit("error", { message: "You are not a player in this match." });
    return;
  }

  await finishMatchByForfeit(io, matchId, user.id, "forfeit");
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
 * Clean up room and game tracking when a socket disconnects.
 *
 * Lobby phase: notifies any remaining players in the room that the opponent
 * left (same as Phase 5.4).
 *
 * Game phase (Phase 5.6): if the socket was participating in an in_progress
 * match, triggers an auto-forfeit so the opponent is declared winner.
 */
function handleDisconnectForLobby(
  socket: AuthSocket,
  io: SocketIOServer,
): void {
  // ── Lobby cleanup ────────────────────────────────────────────────────────
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

  // ── Active game cleanup (Phase 5.6) ──────────────────────────────────────
  const activeMatchId = activeGameBySocketId.get(socket.id);
  if (activeMatchId) {
    activeGameBySocketId.delete(socket.id);

    const user = socket.data.user;
    logger.info(
      { socketId: socket.id, matchId: activeMatchId, userId: user.id },
      "Game: socket disconnected during active game — triggering auto-forfeit.",
    );

    finishMatchByForfeit(io, activeMatchId, user.id, "disconnect").catch(
      (err) => {
        logger.error(
          { err, matchId: activeMatchId },
          "Game: auto-forfeit on disconnect threw.",
        );
      },
    );
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

    socket.on("forfeit", (data) => {
      handleForfeit(authSocket, io, data).catch((err) => {
        logger.error({ err, socketId: socket.id }, "forfeit handler threw.");
      });
    });

    // Phase 6.1: dice roll
    socket.on("roll_dice", (data) => {
      handleRollDice(authSocket, io, data).catch((err) => {
        logger.error({ err, socketId: socket.id }, "roll_dice handler threw.");
      });
    });

    socket.on("leave_room", (data) => {
      handleLeaveRoom(authSocket, data);
    });

    socket.on("disconnect", () => {
      handleDisconnectForLobby(authSocket, io);
    });
  });
}
