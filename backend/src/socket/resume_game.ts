/**
 * Socket.IO resume_game handler.
 *
 * Allows a player to reconnect to an in-progress match after an app restart
 * or network interruption without going through the lobby again.
 *
 * Event: resume_game  { matchId }
 *
 * On failure  → emit resume_failed  { reason }  to the calling socket only.
 * On success  → join socket to existing room, register for auto-forfeit, and
 *               emit resume_game_state  (see payload shape below)  to the
 *               calling socket only.
 *
 * This handler is read-only with respect to game state:
 *  - It does NOT create a new match or room.
 *  - It does NOT restart the turn timer.
 *  - It does NOT modify LudoGameState.
 */

import type { Server as SocketIOServer, Socket } from "socket.io";
import { pool } from "../db/index.js";
import { logger } from "../lib/logger.js";
import {
  getGameState,
  TURN_DURATION_SECONDS,
} from "./game_engine.js";
import { registerActiveGameSocket } from "./game_lobby.js";

// ---------------------------------------------------------------------------
// Local types (mirror game_lobby.ts / game_engine.ts conventions)
// ---------------------------------------------------------------------------

interface SocketUserData {
  id: string;
  player_id: string;
  fullName: string;
  avatar: string | null;
  country: string | null;
}

type AuthSocket = Socket & { data: { user: SocketUserData } };

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * Handle the `resume_game` event emitted by the client.
 *
 * Validation (each failure emits `resume_failed` and returns early):
 *  1. `matchId` must be present in the payload.
 *  2. The match must exist in the DB with `status = 'in_progress'` AND the
 *     calling player must be a participant (`match_players` join).
 *  3. A live `LudoGameState` must exist for the match (`getGameState`).
 *  4. The calling player must be found in the game state.
 *  5. The player must not be eliminated.
 *  6. The player must have `lives > 0`.
 *
 * On success:
 *  - The socket joins the existing Socket.IO room (matchId) — no new room.
 *  - The socket is registered in `activeGameBySocketId` via
 *    `registerActiveGameSocket` so disconnect auto-forfeit fires correctly.
 *  - `resume_game_state` is emitted to the calling socket only.
 */
async function handleResumeGame(
  socket: AuthSocket,
  _io: SocketIOServer,
  data: unknown,
): Promise<void> {
  const user = socket.data.user;
  const matchId = (data as Record<string, unknown> | null)?.["matchId"];

  // ── 1. matchId present ────────────────────────────────────────────────────
  if (!matchId || typeof matchId !== "string") {
    socket.emit("resume_failed", { reason: "resume_game requires matchId." });
    return;
  }

  if (!pool) {
    socket.emit("resume_failed", { reason: "Database unavailable." });
    return;
  }

  // ── 2. Match in_progress + player is a participant ────────────────────────
  const matchResult = await pool.query<{ room_code: string }>(
    `SELECT m.room_code
       FROM matches m
       JOIN match_players mp ON mp.match_id = m.id
      WHERE m.id      = $1
        AND m.status  = 'in_progress'
        AND mp.user_id = $2
      LIMIT 1`,
    [matchId, user.id],
  );

  if (matchResult.rowCount === 0) {
    socket.emit("resume_failed", {
      reason:
        "Match not found, not in progress, or you are not a participant.",
    });
    return;
  }

  const roomCode = matchResult.rows[0]!.room_code;

  // ── 3. Live game state exists ─────────────────────────────────────────────
  const state = getGameState(matchId);
  if (!state) {
    socket.emit("resume_failed", { reason: "Game state not found." });
    return;
  }

  // ── 4. Player found in game state ─────────────────────────────────────────
  const player = state.players.find((p) => p.userId === user.id);
  if (!player) {
    socket.emit("resume_failed", {
      reason: "Player not found in game state.",
    });
    return;
  }

  // ── 5. Player not eliminated ──────────────────────────────────────────────
  if (player.eliminated) {
    socket.emit("resume_failed", { reason: "Player is eliminated." });
    return;
  }

  // ── 6. Player has lives remaining ─────────────────────────────────────────
  if (player.lives <= 0) {
    socket.emit("resume_failed", { reason: "Player has no remaining lives." });
    return;
  }

  // ── All checks passed ─────────────────────────────────────────────────────

  // Rejoin the existing Socket.IO room (idempotent — safe if already joined).
  await socket.join(matchId);

  // Register for auto-forfeit on disconnect (same as active game sockets).
  registerActiveGameSocket(socket.id, matchId);

  // Compute remaining turn time from the stored start timestamp.
  const elapsedSeconds = Math.floor(
    (Date.now() - state.turnStartedAt) / 1000,
  );
  const remainingTurnSeconds = Math.max(
    0,
    TURN_DURATION_SECONDS - elapsedSeconds,
  );

  // Emit resume_game_state to the resuming socket only.
  socket.emit("resume_game_state", {
    matchId: state.matchId,
    roomCode,
    currentTurn: state.currentTurn,
    phase: state.phase,
    diceValue: state.diceValue,
    validMoves: state.validMoves,
    remainingTurnSeconds,
    players: state.players.map((p) => ({
      userId: p.userId,
      color: p.color,
      lives: p.lives,
      eliminated: p.eliminated,
      pawns: p.pawns.map((pawn, index) => ({
        id: index,
        position: pawn.position,
      })),
    })),
  });

  logger.info(
    {
      matchId,
      userId: user.id,
      currentTurn: state.currentTurn,
      phase: state.phase,
      remainingTurnSeconds,
    },
    "Game resume: resume_game_state emitted.",
  );
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

/**
 * Register the `resume_game` event handler on the Socket.IO server.
 * Must be called once during server startup, inside `initSocket`.
 */
export function setupResumeGameHandlers(io: SocketIOServer): void {
  io.on("connection", (socket) => {
    const authSocket = socket as AuthSocket;

    socket.on("resume_game", (data) => {
      handleResumeGame(authSocket, io, data).catch((err) => {
        logger.error(
          { err, socketId: socket.id },
          "resume_game handler threw.",
        );
        socket.emit("resume_failed", { reason: "Internal server error." });
      });
    });
  });
}
