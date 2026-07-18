/**
 * Socket.IO matchmaking handlers — Phase 5.1.
 *
 * Responsibilities:
 *  - Auth middleware: verify JWT from handshake, attach user data to socket.
 *  - find_match event: join queue; pair immediately if an opponent is waiting.
 *  - leave_queue event: remove the player from the queue.
 *  - disconnect: remove the player from the queue on connection loss.
 *  - Pairing logic: atomic dequeue → DB match creation → match_found emit.
 *
 * Queue join/leave is Socket.IO-only.  REST only exposes read-only status.
 */

import type { Server as SocketIOServer, Socket } from "socket.io";
import { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";
import { verifyAccessToken } from "../lib/jwt";
import { findById } from "../services/user.service";
import {
  enqueue,
  dequeue,
  getEntry,
  isQueued,
  queueSize,
  dequeueOpponent,
  type QueueEntry,
} from "../services/matchmaking.queue";
import { createMatch } from "../services/match.service";
import { logger } from "../lib/logger";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Data attached to an authenticated socket after the auth middleware runs. */
interface SocketUserData {
  id: string;
  player_id: string;
  fullName: string;
  avatar: string | null;
}

/** An authenticated socket with user data guaranteed to be present. */
type AuthSocket = Socket & { data: { user: SocketUserData } };

// ---------------------------------------------------------------------------
// Socket.IO auth middleware
// ---------------------------------------------------------------------------

/**
 * Register the JWT authentication middleware on the Socket.IO server.
 *
 * Reads `socket.handshake.auth.token`, verifies it as an access token, and
 * fetches the player's display name and avatar from the database.  Attaches
 * the result to `socket.data.user`.
 *
 * Rejects the connection with an `unauthorized` error when:
 *   - The token is absent, expired, or invalid.
 *   - The user cannot be found in the database.
 *   - The database is unavailable.
 *
 * The rejection message is intentionally generic to avoid leaking JWT details.
 */
function registerAuthMiddleware(io: SocketIOServer): void {
  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.["token"] as string | undefined;

    if (!token || typeof token !== "string") {
      return next(new Error("unauthorized"));
    }

    try {
      const payload = verifyAccessToken(token);

      // Fetch display data — not stored in the JWT
      const user = await findById(payload.sub);
      if (!user) {
        return next(new Error("unauthorized"));
      }

      socket.data["user"] = {
        id: user.id,
        player_id: user.player_id,
        fullName: user.full_name,
        avatar: user.avatar ?? null,
      } satisfies SocketUserData;

      next();
    } catch (err) {
      if (err instanceof TokenExpiredError || err instanceof JsonWebTokenError) {
        return next(new Error("unauthorized"));
      }
      logger.error({ err }, "Socket auth middleware: unexpected error.");
      next(new Error("unauthorized"));
    }
  });
}

// ---------------------------------------------------------------------------
// Pairing logic
// ---------------------------------------------------------------------------

/**
 * Attempt to pair a newly queued player with an existing opponent.
 *
 * ATOMICITY GUARANTEE:
 *   `dequeueOpponent` is synchronous and runs before any `await`.  This means
 *   both players are removed from the in-memory queue before the async DB
 *   write begins.  No third player can claim either slot during the await.
 *
 * On DB failure: the opponent is placed back in the queue and the joining
 * player receives an error event.  The match is not created.
 *
 * @param socket - The authenticated socket of the player who just joined.
 * @param user   - Verified user data attached by the auth middleware.
 * @param io     - The Socket.IO server (needed to emit to the opponent's socketId).
 */
async function attemptPairing(
  socket: AuthSocket,
  user: SocketUserData,
  io: SocketIOServer,
): Promise<void> {
  // ── SYNCHRONOUS: dequeue an opponent before any await ────────────────────
  const opponent = dequeueOpponent(user.id);

  if (!opponent) {
    // No opponent available — add self to queue and wait
    enqueue({
      userId: user.id,
      playerId: user.player_id,
      fullName: user.fullName,
      avatar: user.avatar,
      socketId: socket.id,
      joinedAt: new Date(),
    });

    socket.emit("queue_joined", { queueSize: queueSize() });
    logger.info(
      { userId: user.id, queueSize: queueSize() },
      "Matchmaking: player joined queue.",
    );
    return;
  }

  // ── Both players are out of the queue — create the match in DB ───────────
  const selfEntry: QueueEntry = {
    userId: user.id,
    playerId: user.player_id,
    fullName: user.fullName,
    avatar: user.avatar,
    socketId: socket.id,
    joinedAt: new Date(),
  };

  try {
    const { match, players } = await createMatch(selfEntry, opponent);

    // players[0] = selfEntry, players[1] = opponent (order from createMatch)
    const selfPlayer = players[0]!;
    const opponentPlayer = players[1]!;

    // ── Emit match_found to self ──────────────────────────────────────────
    socket.emit("match_found", {
      matchId: match.id,
      roomCode: match.room_code,
      color: selfPlayer.color,
      opponent: {
        playerId: opponent.playerId,
        fullName: opponent.fullName,
        avatar: opponent.avatar,
      },
    });

    // ── Emit match_found to opponent ──────────────────────────────────────
    io.to(opponent.socketId).emit("match_found", {
      matchId: match.id,
      roomCode: match.room_code,
      color: opponentPlayer.color,
      opponent: {
        playerId: user.player_id,
        fullName: user.fullName,
        avatar: user.avatar,
      },
    });

    logger.info(
      {
        matchId: match.id,
        roomCode: match.room_code,
        player1: user.id,
        player2: opponent.userId,
      },
      "Matchmaking: match created.",
    );
  } catch (err) {
    // DB write failed — restore the opponent to the queue so they are not lost
    enqueue(opponent);

    logger.error({ err }, "Matchmaking: failed to create match; opponent restored to queue.");
    socket.emit("error", { message: "Matchmaking failed. Please try again." });
  }
}

// ---------------------------------------------------------------------------
// Event handlers
// ---------------------------------------------------------------------------

/**
 * Handle the `find_match` event emitted by the client.
 *
 * If the player is already in the queue (e.g. a reconnect), refresh their
 * socketId so future match_found emissions go to the correct socket, then
 * re-acknowledge.  Do not add them twice.
 */
async function handleFindMatch(socket: AuthSocket, io: SocketIOServer): Promise<void> {
  const user = socket.data.user;

  if (isQueued(user.id)) {
    // Reconnect: update the socket ID and re-acknowledge without re-pairing
    const existing = getEntry(user.id)!;
    dequeue(user.id);
    enqueue({ ...existing, socketId: socket.id });
    socket.emit("queue_joined", { queueSize: queueSize() });
    logger.info({ userId: user.id }, "Matchmaking: updated socketId for already-queued player.");
    return;
  }

  await attemptPairing(socket, user, io);
}

/**
 * Handle the `leave_queue` event emitted by the client.
 *
 * Silently succeeds when the player is not in the queue (idempotent).
 */
function handleLeaveQueue(socket: AuthSocket): void {
  const user = socket.data.user;
  const wasQueued = dequeue(user.id);

  if (wasQueued) {
    logger.info({ userId: user.id }, "Matchmaking: player left queue.");
  }

  socket.emit("queue_left", { success: true });
}

/**
 * Handle socket disconnection.
 *
 * Removes the player from the queue if they disconnect while waiting.
 * Uses the socket's ID as a secondary guard so that a reconnected socket
 * with a new ID doesn't accidentally evict the player from a fresh entry.
 */
function handleDisconnect(socket: AuthSocket, reason: string): void {
  const user = socket.data?.["user"] as SocketUserData | undefined;
  if (!user) return;

  const entry = getEntry(user.id);
  if (entry && entry.socketId === socket.id) {
    dequeue(user.id);
    logger.info(
      { userId: user.id, reason },
      "Matchmaking: removed disconnected player from queue.",
    );
  }
}

// ---------------------------------------------------------------------------
// Public setup function
// ---------------------------------------------------------------------------

/**
 * Register the matchmaking auth middleware and event handlers on the Socket.IO
 * server.  Must be called once during server startup, inside `initSocket`.
 *
 * @param io - The already-created Socket.IO server instance.
 */
export function setupMatchmakingHandlers(io: SocketIOServer): void {
  // ── Auth middleware ───────────────────────────────────────────────────────
  registerAuthMiddleware(io);

  // ── Per-connection event handlers ─────────────────────────────────────────
  io.on("connection", (socket) => {
    const authSocket = socket as AuthSocket;
    const user = authSocket.data.user;

    logger.info(
      { socketId: socket.id, userId: user?.id },
      "Authenticated socket connected.",
    );

    socket.on("find_match", () => {
      handleFindMatch(authSocket, io).catch((err) => {
        logger.error({ err, socketId: socket.id }, "find_match handler threw.");
      });
    });

    socket.on("leave_queue", () => {
      handleLeaveQueue(authSocket);
    });

    socket.on("disconnect", (reason) => {
      handleDisconnect(authSocket, reason);
    });
  });
}
