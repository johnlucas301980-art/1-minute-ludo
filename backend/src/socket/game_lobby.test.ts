import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";

const {
  pool,
  createGameState,
  clearGameState,
  handleRollDice,
  handleMovePawn,
  checkCountryAccess,
} = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
  createGameState: vi.fn(),
  clearGameState: vi.fn(),
  handleRollDice: vi.fn().mockResolvedValue(undefined),
  handleMovePawn: vi.fn().mockResolvedValue(undefined),
  checkCountryAccess: vi.fn(),
}));

vi.mock("../db/index.js", () => ({ pool }));
vi.mock("../lib/logger.js", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));
vi.mock("./game_engine.js", () => ({
  createGameState,
  clearGameState,
  handleRollDice,
  handleMovePawn,
}));
vi.mock("../services/country.service.js", () => ({ checkCountryAccess }));

import { setupGameLobbyHandlers } from "./game_lobby.js";

type EventHandler = (...args: unknown[]) => unknown;

function makeSocket(userId: string, socketId: string, country: string | null = null) {
  const handlers = new Map<string, EventHandler>();
  const roomTarget = { emit: vi.fn() };
  const socket = {
    id: socketId,
    data: {
      user: {
        id: userId,
        player_id: `LUD-${userId}`,
        fullName: `Player ${userId}`,
        avatar: null,
        country,
      },
    },
    handlers,
    emit: vi.fn(),
    join: vi.fn().mockResolvedValue(undefined),
    leave: vi.fn(),
    to: vi.fn(() => roomTarget),
    roomTarget,
    on: vi.fn((event: string, handler: EventHandler) => {
      handlers.set(event, handler);
    }),
  };
  return socket;
}

function makeIo() {
  const handlers = new Map<string, EventHandler>();
  const roomTargets = new Map<string, { emit: ReturnType<typeof vi.fn> }>();
  const io = {
    handlers,
    roomTargets,
    on: vi.fn((event: string, handler: EventHandler) => {
      handlers.set(event, handler);
    }),
    to: vi.fn((room: string) => {
      if (!roomTargets.has(room)) roomTargets.set(room, { emit: vi.fn() });
      return roomTargets.get(room)!;
    }),
    in: vi.fn((room: string) => ({
      fetchSockets: vi
        .fn()
        .mockResolvedValue([{ id: "socket-a" }, { id: "socket-b" }]),
      room,
    })),
  };
  return io;
}

async function connectSocket(
  io: ReturnType<typeof makeIo>,
  socket: ReturnType<typeof makeSocket>,
) {
  await io.handlers.get("connection")!(socket);
}

async function emitEvent(
  socket: ReturnType<typeof makeSocket>,
  event: string,
  data?: unknown,
) {
  socket.handlers.get(event)!(data);
  await vi.waitFor(() => undefined, { timeout: 20 });
}

function setupSockets() {
  const io = makeIo();
  const socketA = makeSocket("user-a", "socket-a");
  const socketB = makeSocket("user-b", "socket-b");
  setupGameLobbyHandlers(io as never);
  return { io, socketA, socketB };
}

beforeEach(() => {
  vi.resetAllMocks();
  handleRollDice.mockResolvedValue(undefined);
  handleMovePawn.mockResolvedValue(undefined);
  vi.useFakeTimers();
  // Default: gameplay allowed
  checkCountryAccess.mockResolvedValue({ allowed: true });
});

afterEach(() => {
  vi.runOnlyPendingTimers();
  vi.useRealTimers();
});

describe("setupGameLobbyHandlers", () => {
  it("registers all lobby and game event handlers for each connection", async () => {
    const { io, socketA } = setupSockets();

    await connectSocket(io, socketA);

    expect(socketA.handlers.has("join_room")).toBe(true);
    expect(socketA.handlers.has("forfeit")).toBe(true);
    expect(socketA.handlers.has("roll_dice")).toBe(true);
    expect(socketA.handlers.has("move_pawn")).toBe(true);
    expect(socketA.handlers.has("leave_room")).toBe(true);
    expect(socketA.handlers.has("disconnect")).toBe(true);
  });

  it("rejects join_room without a match id", async () => {
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "join_room", {});

    expect(socketA.emit).toHaveBeenCalledWith("error", {
      message: "join_room requires matchId.",
    });
    expect(pool.query).not.toHaveBeenCalled();
  });

  it("rejects a player who is not a participant", async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "join_room", { matchId: "match-1" });

    expect(pool.query).toHaveBeenCalledWith(
      "SELECT id FROM match_players WHERE match_id = $1 AND user_id = $2",
      ["match-1", "user-a"],
    );
    expect(socketA.emit).toHaveBeenCalledWith("error", {
      message: "You are not a player in this match.",
    });
    expect(socketA.join).not.toHaveBeenCalled();
  });

  it("tracks the first join and emits its player count", async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] });
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "join_room", { matchId: "match-1" });

    expect(socketA.join).toHaveBeenCalledWith("match-1");
    expect(socketA.emit).toHaveBeenCalledWith("room_joined", {
      matchId: "match-1",
      playerCount: 1,
    });
    expect(io.roomTargets.get("match-1")).toBeUndefined();
  });

  it("emits room_ready after the second player and starts the match after the delay", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] })
      .mockResolvedValueOnce({ rows: [{ id: "match-player-b" }] })
      .mockResolvedValueOnce({
        rows: [
          { color: "red", user_id: "user-a" },
          { color: "blue", user_id: "user-b" },
        ],
      })
      .mockResolvedValueOnce({});
    vi.spyOn(Math, "random").mockReturnValue(0.75);
    const { io, socketA, socketB } = setupSockets();
    await connectSocket(io, socketA);
    await connectSocket(io, socketB);

    await emitEvent(socketA, "join_room", { matchId: "match-1" });
    await emitEvent(socketB, "join_room", { matchId: "match-1" });

    expect(io.roomTargets.get("match-1")?.emit).toHaveBeenCalledWith(
      "room_ready",
      {
        matchId: "match-1",
      },
    );
    expect(pool.query).toHaveBeenCalledTimes(2);

    await vi.advanceTimersByTimeAsync(2500);

    expect(pool.query).toHaveBeenCalledWith(
      "SELECT color, user_id FROM match_players WHERE match_id = $1",
      ["match-1"],
    );
    expect(pool.query).toHaveBeenCalledWith(
      "UPDATE matches SET status = 'in_progress', started_at = NOW() WHERE id = $1",
      ["match-1"],
    );
    expect(io.roomTargets.get("match-1")?.emit).toHaveBeenCalledWith(
      "game_start",
      {
        matchId: "match-1",
        firstTurn: "blue",
      },
    );
    expect(createGameState).toHaveBeenCalledWith(
      "match-1",
      [
        { userId: "user-a", color: "red" },
        { userId: "user-b", color: "blue" },
      ],
      "blue",
    );
    expect(io.in).toHaveBeenCalledWith("match-1");
  });

  it("does not start a match when fewer than two database players are returned", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] })
      .mockResolvedValueOnce({ rows: [{ id: "match-player-b" }] })
      .mockResolvedValueOnce({ rows: [{ color: "red", user_id: "user-a" }] });
    const { io, socketA, socketB } = setupSockets();
    await connectSocket(io, socketA);
    await connectSocket(io, socketB);

    await emitEvent(socketA, "join_room", { matchId: "match-1" });
    await emitEvent(socketB, "join_room", { matchId: "match-1" });
    await vi.advanceTimersByTimeAsync(2500);

    expect(createGameState).not.toHaveBeenCalled();
    expect(io.roomTargets.get("match-1")?.emit).not.toHaveBeenCalledWith(
      "game_start",
      expect.anything(),
    );
    expect(pool.query).toHaveBeenCalledTimes(3);
  });

  it("leaves a room and notifies the remaining opponent", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] })
      .mockResolvedValueOnce({ rows: [{ id: "match-player-b" }] });
    const { io, socketA, socketB } = setupSockets();
    await connectSocket(io, socketA);
    await connectSocket(io, socketB);
    await emitEvent(socketA, "join_room", { matchId: "match-1" });
    await emitEvent(socketB, "join_room", { matchId: "match-1" });

    await emitEvent(socketA, "leave_room", { matchId: "match-1" });

    expect(socketA.leave).toHaveBeenCalledWith("match-1");
    expect(socketA.emit).toHaveBeenCalledWith("room_left", {
      matchId: "match-1",
    });
    expect(socketA.roomTarget.emit).toHaveBeenCalledWith("opponent_left", {
      matchId: "match-1",
    });
  });

  it("ignores leave_room payloads without a match id", async () => {
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "leave_room", {});

    expect(socketA.leave).not.toHaveBeenCalled();
    expect(socketA.emit).not.toHaveBeenCalled();
  });

  it("rejects forfeit without a match id", async () => {
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "forfeit", {});

    expect(socketA.emit).toHaveBeenCalledWith("error", {
      message: "forfeit requires matchId.",
    });
    expect(pool.query).not.toHaveBeenCalled();
  });

  it("rejects forfeit by a non-participant", async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "forfeit", { matchId: "match-1" });

    expect(socketA.emit).toHaveBeenCalledWith("error", {
      message: "You are not a player in this match.",
    });
    expect(pool.query).toHaveBeenCalledOnce();
  });

  it("finishes an in-progress match when a player forfeits", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] })
      .mockResolvedValueOnce({ rows: [{ status: "in_progress" }] })
      .mockResolvedValueOnce({ rows: [{ user_id: "user-b" }] })
      .mockResolvedValueOnce({});
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "forfeit", { matchId: "match-1" });
    await vi.waitFor(() => {
      expect(pool.query).toHaveBeenCalledTimes(4);
    });

    expect(pool.query).toHaveBeenNthCalledWith(
      3,
      expect.stringMatching(/SELECT user_id[\s\S]*user_id\s+!=\s+\$2/),
      ["match-1", "user-a"],
    );
    expect(pool.query).toHaveBeenNthCalledWith(
      4,
      expect.stringMatching(/SET status\s+= 'finished'/),
      ["user-b", "match-1"],
    );
    expect(clearGameState).toHaveBeenCalledWith("match-1");
    expect(io.roomTargets.get("match-1")?.emit).toHaveBeenCalledWith(
      "game_over",
      {
        matchId: "match-1",
        winnerId: "user-b",
        reason: "forfeit",
      },
    );
  });

  it("does nothing when a forfeited match is already terminal", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] })
      .mockResolvedValueOnce({ rows: [{ status: "finished" }] });
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);

    await emitEvent(socketA, "forfeit", { matchId: "match-1" });

    expect(pool.query).toHaveBeenCalledTimes(2);
    expect(clearGameState).not.toHaveBeenCalled();
    expect(io.roomTargets.get("match-1")).toBeUndefined();
  });

  it("cancels a pending match when a joined player disconnects", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] })
      .mockResolvedValueOnce({ rows: [{ id: "match-player-b" }] })
      .mockResolvedValueOnce({});
    const { io, socketA, socketB } = setupSockets();
    await connectSocket(io, socketA);
    await connectSocket(io, socketB);
    await emitEvent(socketA, "join_room", { matchId: "match-1" });
    await emitEvent(socketB, "join_room", { matchId: "match-1" });

    await emitEvent(socketA, "disconnect");
    await vi.waitFor(() => {
      expect(pool.query).toHaveBeenCalledWith(
        expect.stringMatching(/SET status = 'cancelled'/),
        ["match-1"],
      );
    });

    expect(io.to).toHaveBeenCalledWith("socket-b");
    expect(io.roomTargets.get("socket-b")?.emit).toHaveBeenCalledWith(
      "game_over",
      {
        matchId: "match-1",
        winnerId: "user-b",
        reason: "disconnect",
      },
    );
    expect(io.roomTargets.get("match-1")?.emit).not.toHaveBeenCalledWith(
      "game_start",
      expect.anything(),
    );
  });

  it("auto-forfeits an active match when a player disconnects", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] })
      .mockResolvedValueOnce({ rows: [{ id: "match-player-b" }] })
      .mockResolvedValueOnce({
        rows: [
          { color: "red", user_id: "user-a" },
          { color: "blue", user_id: "user-b" },
        ],
      })
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({ rows: [{ status: "in_progress" }] })
      .mockResolvedValueOnce({ rows: [{ user_id: "user-b" }] })
      .mockResolvedValueOnce({});
    const { io, socketA, socketB } = setupSockets();
    await connectSocket(io, socketA);
    await connectSocket(io, socketB);
    await emitEvent(socketA, "join_room", { matchId: "match-1" });
    await emitEvent(socketB, "join_room", { matchId: "match-1" });
    await vi.advanceTimersByTimeAsync(2500);

    await emitEvent(socketA, "disconnect");
    await vi.waitFor(() => {
      expect(clearGameState).toHaveBeenCalledWith("match-1");
    });

    expect(io.roomTargets.get("match-1")?.emit).toHaveBeenCalledWith(
      "game_over",
      {
        matchId: "match-1",
        winnerId: "user-b",
        reason: "disconnect",
      },
    );
  });

  it("delegates roll_dice to the game engine", async () => {
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);
    const payload = { matchId: "match-1", dice: 6 };

    await emitEvent(socketA, "roll_dice", payload);

    await vi.waitFor(() => {
      expect(handleRollDice).toHaveBeenCalledWith(socketA, io, payload);
    });
  });

  it("delegates move_pawn to the game engine", async () => {
    const { io, socketA } = setupSockets();
    await connectSocket(io, socketA);
    const payload = { matchId: "match-1", pawnIndex: 2 };

    await emitEvent(socketA, "move_pawn", payload);

    await vi.waitFor(() => {
      expect(handleMovePawn).toHaveBeenCalledWith(socketA, io, payload);
    });
  });

  // ── join_room: allow_gameplay country check ────────────────────────────────

  it("blocks join_room and emits error when allow_gameplay is false for the player's country", async () => {
    checkCountryAccess.mockResolvedValue({
      allowed: false,
      message: "This game is currently unavailable in your country due to local regulations.",
    });
    const io = makeIo();
    // Socket with country set to "NG"
    const socketNG = makeSocket("user-a", "socket-a", "NG");
    setupGameLobbyHandlers(io as never);
    await connectSocket(io, socketNG);

    await emitEvent(socketNG, "join_room", { matchId: "match-1" });

    expect(checkCountryAccess).toHaveBeenCalledWith("NG", "gameplay");
    expect(socketNG.emit).toHaveBeenCalledWith("error", {
      message: "Gameplay is currently unavailable in your country.",
    });
    expect(pool.query).not.toHaveBeenCalled();
    expect(socketNG.join).not.toHaveBeenCalled();
  });

  it("allows join_room when allow_gameplay is true for the player's country", async () => {
    checkCountryAccess.mockResolvedValue({ allowed: true });
    pool.query.mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] });
    const io = makeIo();
    const socketNG = makeSocket("user-a", "socket-a", "NG");
    setupGameLobbyHandlers(io as never);
    await connectSocket(io, socketNG);

    // Fire the handler directly; use vi.waitFor so the async chain (checkCountryAccess
    // + pool.query + socket.join) fully resolves before asserting.
    socketNG.handlers.get("join_room")!({ matchId: "match-1" });
    await vi.waitFor(() => {
      expect(socketNG.emit).toHaveBeenCalledWith("room_joined", {
        matchId: "match-1",
        playerCount: 1,
      });
    });

    expect(checkCountryAccess).toHaveBeenCalledWith("NG", "gameplay");
    expect(socketNG.join).toHaveBeenCalledWith("match-1");
  });

  it("allows join_room when the player has no country set (fail-open)", async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: "match-player-a" }] });
    const { io, socketA } = setupSockets(); // socketA has country: null
    await connectSocket(io, socketA);

    await emitEvent(socketA, "join_room", { matchId: "match-1" });

    expect(checkCountryAccess).not.toHaveBeenCalled();
    expect(socketA.join).toHaveBeenCalledWith("match-1");
  });
});
