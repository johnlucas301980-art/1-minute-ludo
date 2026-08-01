import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../db/index.js", () => ({ pool: null }));
vi.mock("../lib/logger.js", () => ({
  logger: {
    info: vi.fn(),
    error: vi.fn(),
    warn: vi.fn(),
  },
}));
vi.mock("../services/notification.service.js", () => ({
  createMatchCompletionNotifications: vi.fn(),
}));

import type { Server as SocketIOServer } from "socket.io";
import {
  SAFE_ABSOLUTE_POSITIONS,
  clearGameState,
  createGameState,
  getGameState,
  isAbsoluteSafe,
  nextPlayerColor,
  relativeToAbsolute,
  type LudoGameState,
} from "./game_engine.js";

// Minimal Socket.IO server mock — only the `to().emit()` chain is needed
// by scheduleTurnTimer when a timer fires during tests.
const mockIo = {
  to: vi.fn().mockReturnValue({ emit: vi.fn() }),
} as unknown as SocketIOServer;

const players = [
  { userId: "red-user", color: "red" as const },
  { userId: "blue-user", color: "blue" as const },
] as const;

beforeEach(() => {
  clearGameState("match-1");
  vi.clearAllMocks();
});

describe("game engine pure helpers", () => {
  it("creates a fresh waiting game state with four pawns per player", () => {
    createGameState("match-1", [...players], "red", mockIo);

    const state = getGameState("match-1");
    expect(state).toMatchObject({
      matchId: "match-1",
      players: [
        {
          userId: "red-user",
          color: "red",
          lives: 5,
          eliminated: false,
          pawns: [{ position: 0 }, { position: 0 }, { position: 0 }, { position: 0 }],
        },
        {
          userId: "blue-user",
          color: "blue",
          lives: 5,
          eliminated: false,
          pawns: [{ position: 0 }, { position: 0 }, { position: 0 }, { position: 0 }],
        },
      ],
      currentTurn: "red",
      diceValue: null,
      validMoves: [],
      phase: "waiting_roll",
    });
    expect(state!.turnStartedAt).toBeGreaterThan(0);
    expect(state!.turnTimer).not.toBeNull();
  });

  it("clears a stored game state", () => {
    createGameState("match-1", [...players], "blue", mockIo);

    clearGameState("match-1");

    expect(getGameState("match-1")).toBeUndefined();
  });

  it("returns no state for an unknown match", () => {
    expect(getGameState("missing-match")).toBeUndefined();
  });

  it("converts color-relative positions to absolute track positions", () => {
    expect(relativeToAbsolute(1, "red")).toBe(0);
    expect(relativeToAbsolute(1, "blue")).toBe(13);
    expect(relativeToAbsolute(1, "green")).toBe(26);
    expect(relativeToAbsolute(1, "yellow")).toBe(39);
    expect(relativeToAbsolute(52, "red")).toBe(51);
  });

  it("identifies the configured safe squares", () => {
    expect(SAFE_ABSOLUTE_POSITIONS).toHaveLength(8);
    expect(isAbsoluteSafe(0)).toBe(true);
    expect(isAbsoluteSafe(47)).toBe(true);
    expect(isAbsoluteSafe(1)).toBe(false);
  });

  it("returns the opposing player color", () => {
    createGameState("match-1", [...players], "red", mockIo);
    const state = getGameState("match-1")!;

    expect(nextPlayerColor(state)).toBe("blue");

    state.currentTurn = "blue";
    expect(nextPlayerColor(state)).toBe("red");
  });

  it("throws when no opposing player color can be found", () => {
    const pawnRow: [
      { position: number },
      { position: number },
      { position: number },
      { position: number },
    ] = [{ position: 0 }, { position: 0 }, { position: 0 }, { position: 0 }];

    const invalidState: LudoGameState = {
      matchId: "invalid",
      players: [
        { userId: "red-user",        color: "red", lives: 5, eliminated: false, pawns: pawnRow },
        { userId: "second-red-user", color: "red", lives: 5, eliminated: false, pawns: pawnRow },
      ],
      currentTurn: "red",
      diceValue: null,
      validMoves: [],
      phase: "waiting_roll",
      turnTimer: null,
      turnStartedAt: 0,
    };

    expect(() => nextPlayerColor(invalidState)).toThrow(
      "cannot determine next player colour",
    );
  });
});
