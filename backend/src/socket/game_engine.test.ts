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

const players = [
  { userId: "red-user", color: "red" as const },
  { userId: "blue-user", color: "blue" as const },
] as const;

beforeEach(() => {
  clearGameState("match-1");
});

describe("game engine pure helpers", () => {
  it("creates a fresh waiting game state with four pawns per player", () => {
    createGameState("match-1", [...players], "red");

    expect(getGameState("match-1")).toEqual({
      matchId: "match-1",
      players: [
        {
          userId: "red-user",
          color: "red",
          pawns: [{ position: 0 }, { position: 0 }, { position: 0 }, { position: 0 }],
        },
        {
          userId: "blue-user",
          color: "blue",
          pawns: [{ position: 0 }, { position: 0 }, { position: 0 }, { position: 0 }],
        },
      ],
      currentTurn: "red",
      diceValue: null,
      validMoves: [],
      phase: "waiting_roll",
    });
  });

  it("clears a stored game state", () => {
    createGameState("match-1", [...players], "blue");

    clearGameState("match-1");

    expect(getGameState("match-1")).toBeUndefined();
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
    createGameState("match-1", [...players], "red");
    const state = getGameState("match-1")!;

    expect(nextPlayerColor(state)).toBe("blue");

    state.currentTurn = "blue";
    expect(nextPlayerColor(state)).toBe("red");
  });

  it("throws when no opposing player color can be found", () => {
    const invalidState = {
      matchId: "invalid",
      players: [
        {
          userId: "red-user",
          color: "red",
          pawns: [{ position: 0 }, { position: 0 }, { position: 0 }, { position: 0 }],
        },
        {
          userId: "second-red-user",
          color: "red",
          pawns: [{ position: 0 }, { position: 0 }, { position: 0 }, { position: 0 }],
        },
      ],
      currentTurn: "red",
      diceValue: null,
      validMoves: [],
      phase: "waiting_roll",
    } satisfies LudoGameState;

    expect(() => nextPlayerColor(invalidState)).toThrow(
      "cannot determine next player colour",
    );
  });
});