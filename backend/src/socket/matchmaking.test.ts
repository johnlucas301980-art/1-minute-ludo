import { beforeEach, describe, expect, it, vi } from "vitest";
import { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const {
  verifyAccessToken,
  findById,
  enqueue,
  dequeue,
  getEntry,
  isQueued,
  queueSize,
  dequeueOpponent,
  createMatch,
} = vi.hoisted(() => ({
  verifyAccessToken: vi.fn(),
  findById: vi.fn(),
  enqueue: vi.fn(),
  dequeue: vi.fn(),
  getEntry: vi.fn(),
  isQueued: vi.fn(),
  queueSize: vi.fn().mockReturnValue(0),
  dequeueOpponent: vi.fn(),
  createMatch: vi.fn(),
}));

vi.mock("../lib/jwt.js", () => ({ verifyAccessToken }));
vi.mock("../services/user.service.js", () => ({ findById }));
vi.mock("../services/matchmaking.queue.js", () => ({
  enqueue,
  dequeue,
  getEntry,
  isQueued,
  queueSize,
  dequeueOpponent,
}));
vi.mock("../services/match.service.js", () => ({ createMatch }));
vi.mock("../lib/logger.js", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

import { setupMatchmakingHandlers } from "./matchmaking.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type NextFn = (err?: Error) => void;
type MiddlewareFn = (socket: unknown, next: NextFn) => Promise<void>;
type EventHandler = (...args: unknown[]) => unknown;

/** Build a minimal fake socket for auth middleware tests. */
function makeHandshakeSocket(token: string | undefined) {
  return {
    id: "socket-x",
    handshake: { auth: token !== undefined ? { token } : {} },
    data: {} as Record<string, unknown>,
  };
}

/** Build a fully authenticated socket with pre-populated user data. */
function makeAuthSocket(userId = "user-a", socketId = "socket-a") {
  const handlers = new Map<string, EventHandler>();
  return {
    id: socketId,
    handshake: { auth: { token: "valid-token" } },
    data: {
      user: {
        id: userId,
        player_id: `LUD-${userId}`,
        fullName: `Player ${userId}`,
        avatar: null,
      },
    },
    handlers,
    emit: vi.fn(),
    on: vi.fn((event: string, handler: EventHandler) => {
      handlers.set(event, handler);
    }),
  };
}

/** Build a fake Socket.IO server that captures use() and on() calls. */
function makeIo() {
  let authMiddleware: MiddlewareFn | null = null;
  const connectionHandlers: EventHandler[] = [];
  const roomTargets = new Map<string, { emit: ReturnType<typeof vi.fn> }>();

  const io = {
    use: vi.fn((fn: MiddlewareFn) => {
      authMiddleware = fn;
    }),
    on: vi.fn((event: string, handler: EventHandler) => {
      if (event === "connection") connectionHandlers.push(handler);
    }),
    to: vi.fn((id: string) => {
      if (!roomTargets.has(id)) roomTargets.set(id, { emit: vi.fn() });
      return roomTargets.get(id)!;
    }),
    get _authMiddleware() {
      return authMiddleware;
    },
    get _connectionHandlers() {
      return connectionHandlers;
    },
    roomTargets,
  };
  return io;
}

/** Run the auth middleware against a socket and return {err}. */
async function runAuthMiddleware(
  io: ReturnType<typeof makeIo>,
  socket: ReturnType<typeof makeHandshakeSocket>,
): Promise<{ err: Error | undefined }> {
  return new Promise((resolve) => {
    io._authMiddleware!(socket, (err) => resolve({ err }));
  });
}

/** Trigger a connection event and return the socket passed to handlers. */
async function connectSocket(
  io: ReturnType<typeof makeIo>,
  socket: ReturnType<typeof makeAuthSocket>,
) {
  for (const handler of io._connectionHandlers) {
    await handler(socket);
  }
}

/** Emit an event from a socket and yield to microtasks. */
async function emitEvent(
  socket: ReturnType<typeof makeAuthSocket>,
  event: string,
  data?: unknown,
) {
  const handler = socket.handlers.get(event);
  if (handler) await Promise.resolve(handler(data));
  await vi.waitFor(() => undefined, { timeout: 20 });
}

// ---------------------------------------------------------------------------
// Test setup
// ---------------------------------------------------------------------------

beforeEach(() => {
  vi.resetAllMocks();
  queueSize.mockReturnValue(0);
});

// ---------------------------------------------------------------------------
// Auth middleware
// ---------------------------------------------------------------------------

describe("auth middleware", () => {
  it("rejects the connection when the token is absent", async () => {
    const io = makeIo();
    setupMatchmakingHandlers(io as never);

    const socket = makeHandshakeSocket(undefined);
    const { err } = await runAuthMiddleware(io, socket);

    expect(err?.message).toBe("unauthorized");
    expect(verifyAccessToken).not.toHaveBeenCalled();
  });

  it("rejects the connection when the token is expired", async () => {
    verifyAccessToken.mockImplementation(() => {
      throw new TokenExpiredError("jwt expired", new Date());
    });
    const io = makeIo();
    setupMatchmakingHandlers(io as never);

    const { err } = await runAuthMiddleware(io, makeHandshakeSocket("expired-token"));

    expect(err?.message).toBe("unauthorized");
    expect(findById).not.toHaveBeenCalled();
  });

  it("rejects the connection when the token signature is invalid", async () => {
    verifyAccessToken.mockImplementation(() => {
      throw new JsonWebTokenError("invalid signature");
    });
    const io = makeIo();
    setupMatchmakingHandlers(io as never);

    const { err } = await runAuthMiddleware(io, makeHandshakeSocket("bad-token"));

    expect(err?.message).toBe("unauthorized");
  });

  it("rejects the connection when the user cannot be found", async () => {
    verifyAccessToken.mockReturnValue({ sub: "user-a" });
    findById.mockResolvedValue(null);
    const io = makeIo();
    setupMatchmakingHandlers(io as never);

    const { err } = await runAuthMiddleware(io, makeHandshakeSocket("valid-token"));

    expect(err?.message).toBe("unauthorized");
  });

  it("rejects the connection on an unexpected database error", async () => {
    verifyAccessToken.mockReturnValue({ sub: "user-a" });
    findById.mockRejectedValue(new Error("db down"));
    const io = makeIo();
    setupMatchmakingHandlers(io as never);

    const { err } = await runAuthMiddleware(io, makeHandshakeSocket("valid-token"));

    expect(err?.message).toBe("unauthorized");
  });

  it("accepts the connection and populates socket.data.user", async () => {
    verifyAccessToken.mockReturnValue({ sub: "user-a" });
    findById.mockResolvedValue({
      id: "user-a",
      player_id: "LUD-001",
      full_name: "Alice",
      avatar: "https://example.com/avatar.png",
    });
    const io = makeIo();
    setupMatchmakingHandlers(io as never);

    const socket = makeHandshakeSocket("valid-token");
    const { err } = await runAuthMiddleware(io, socket);

    expect(err).toBeUndefined();
    expect(socket.data["user"]).toEqual({
      id: "user-a",
      player_id: "LUD-001",
      fullName: "Alice",
      avatar: "https://example.com/avatar.png",
    });
  });
});

// ---------------------------------------------------------------------------
// Connection — event handler registration
// ---------------------------------------------------------------------------

describe("setupMatchmakingHandlers", () => {
  it("registers find_match, leave_queue, and disconnect handlers on connection", async () => {
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket();

    await connectSocket(io, socket);

    expect(socket.handlers.has("find_match")).toBe(true);
    expect(socket.handlers.has("leave_queue")).toBe(true);
    expect(socket.handlers.has("disconnect")).toBe(true);
  });

  // ── find_match: already queued ─────────────────────────────────────────────

  it("refreshes socketId and re-acknowledges when the player is already queued", async () => {
    isQueued.mockReturnValue(true);
    getEntry.mockReturnValue({
      userId: "user-a",
      playerId: "LUD-user-a",
      fullName: "Player user-a",
      avatar: null,
      socketId: "old-socket",
      joinedAt: new Date(),
    });
    queueSize.mockReturnValue(1);
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a", "new-socket");
    await connectSocket(io, socket);

    await emitEvent(socket, "find_match");

    expect(dequeue).toHaveBeenCalledWith("user-a");
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({ socketId: "new-socket" }),
    );
    expect(socket.emit).toHaveBeenCalledWith("queue_joined", { queueSize: 1 });
    expect(createMatch).not.toHaveBeenCalled();
  });

  // ── find_match: no opponent (join queue) ───────────────────────────────────

  it("adds the player to the queue when no opponent is available", async () => {
    isQueued.mockReturnValue(false);
    dequeueOpponent.mockReturnValue(undefined);
    queueSize.mockReturnValue(1);
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a", "socket-a");
    await connectSocket(io, socket);

    await emitEvent(socket, "find_match");

    expect(dequeueOpponent).toHaveBeenCalledWith("user-a");
    expect(enqueue).toHaveBeenCalledWith(
      expect.objectContaining({ userId: "user-a", socketId: "socket-a" }),
    );
    expect(socket.emit).toHaveBeenCalledWith("queue_joined", { queueSize: 1 });
    expect(createMatch).not.toHaveBeenCalled();
  });

  // ── find_match: opponent available (pair and create match) ─────────────────

  it("pairs players and emits match_found to both when an opponent is available", async () => {
    const opponent = {
      userId: "user-b",
      playerId: "LUD-user-b",
      fullName: "Player user-b",
      avatar: null,
      socketId: "socket-b",
      joinedAt: new Date(),
    };
    isQueued.mockReturnValue(false);
    dequeueOpponent.mockReturnValue(opponent);
    createMatch.mockResolvedValue({
      match: { id: "match-1", room_code: "ABCD" },
      players: [
        { color: "red" },   // self
        { color: "blue" },  // opponent
      ],
    });
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a", "socket-a");
    await connectSocket(io, socket);

    await emitEvent(socket, "find_match");
    await vi.waitFor(() => expect(createMatch).toHaveBeenCalled());

    expect(createMatch).toHaveBeenCalledWith(
      expect.objectContaining({ userId: "user-a" }),
      opponent,
    );

    // Emit to self
    expect(socket.emit).toHaveBeenCalledWith(
      "match_found",
      expect.objectContaining({
        matchId: "match-1",
        roomCode: "ABCD",
        color: "red",
        opponent: expect.objectContaining({ playerId: "LUD-user-b" }),
      }),
    );

    // Emit to opponent
    expect(io.to).toHaveBeenCalledWith("socket-b");
    expect(io.roomTargets.get("socket-b")?.emit).toHaveBeenCalledWith(
      "match_found",
      expect.objectContaining({
        matchId: "match-1",
        roomCode: "ABCD",
        color: "blue",
        opponent: expect.objectContaining({ playerId: "LUD-user-a" }),
      }),
    );
  });

  // ── find_match: DB failure during pairing ──────────────────────────────────

  it("restores the opponent to the queue and emits error on DB failure", async () => {
    const opponent = {
      userId: "user-b",
      playerId: "LUD-user-b",
      fullName: "Player user-b",
      avatar: null,
      socketId: "socket-b",
      joinedAt: new Date(),
    };
    isQueued.mockReturnValue(false);
    dequeueOpponent.mockReturnValue(opponent);
    createMatch.mockRejectedValue(new Error("db error"));
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a", "socket-a");
    await connectSocket(io, socket);

    await emitEvent(socket, "find_match");
    await vi.waitFor(() => expect(enqueue).toHaveBeenCalled());

    expect(enqueue).toHaveBeenCalledWith(opponent);
    expect(socket.emit).toHaveBeenCalledWith("error", {
      message: "Matchmaking failed. Please try again.",
    });
  });

  // ── leave_queue ────────────────────────────────────────────────────────────

  it("removes the player from the queue and emits queue_left", async () => {
    dequeue.mockReturnValue(true);
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a");
    await connectSocket(io, socket);

    await emitEvent(socket, "leave_queue");

    expect(dequeue).toHaveBeenCalledWith("user-a");
    expect(socket.emit).toHaveBeenCalledWith("queue_left", { success: true });
  });

  it("emits queue_left even when the player was not queued (idempotent)", async () => {
    dequeue.mockReturnValue(false);
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a");
    await connectSocket(io, socket);

    await emitEvent(socket, "leave_queue");

    expect(socket.emit).toHaveBeenCalledWith("queue_left", { success: true });
  });

  // ── disconnect ─────────────────────────────────────────────────────────────

  it("removes the player from the queue on disconnect when socketId matches", async () => {
    getEntry.mockReturnValue({
      userId: "user-a",
      socketId: "socket-a",
      joinedAt: new Date(),
    });
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a", "socket-a");
    await connectSocket(io, socket);

    await emitEvent(socket, "disconnect", "transport close");

    expect(getEntry).toHaveBeenCalledWith("user-a");
    expect(dequeue).toHaveBeenCalledWith("user-a");
  });

  it("does not remove the player when the socketId no longer matches", async () => {
    getEntry.mockReturnValue({
      userId: "user-a",
      socketId: "socket-new",   // reconnected with a newer socket
      joinedAt: new Date(),
    });
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a", "socket-old");
    await connectSocket(io, socket);

    await emitEvent(socket, "disconnect", "transport close");

    expect(dequeue).not.toHaveBeenCalled();
  });

  it("does nothing on disconnect when the player is not in the queue", async () => {
    getEntry.mockReturnValue(undefined);
    const io = makeIo();
    setupMatchmakingHandlers(io as never);
    const socket = makeAuthSocket("user-a");
    await connectSocket(io, socket);

    await emitEvent(socket, "disconnect", "server namespace disconnect");

    expect(dequeue).not.toHaveBeenCalled();
  });
});
