import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const { getLeaderboard } = vi.hoisted(() => ({
  getLeaderboard: vi.fn(),
}));

vi.mock("../services/leaderboard.service.js", () => ({ getLeaderboard }));
vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import { getLeaderboardHandler } from "./leaderboard.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq(): Request {
  return { log: { error: vi.fn() } } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("getLeaderboardHandler", () => {
  it("returns 200 with serialized leaderboard rows on success", async () => {
    getLeaderboard.mockResolvedValue([
      { rank: "1", player_id: "LUD-001", full_name: "Alice", avatar: null, wins: 10 },
      { rank: "2", player_id: "LUD-002", full_name: "Bob", avatar: "https://img.test/b.png", wins: 5 },
    ]);

    const res = makeRes();
    await getLeaderboardHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        leaderboard: [
          { rank: 1, player_id: "LUD-001", full_name: "Alice", avatar: null, wins: 10 },
          { rank: 2, player_id: "LUD-002", full_name: "Bob", avatar: "https://img.test/b.png", wins: 5 },
        ],
      },
    });
  });

  it("returns an empty leaderboard array when no players exist", async () => {
    getLeaderboard.mockResolvedValue([]);

    const res = makeRes();
    await getLeaderboardHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { leaderboard: [] } });
  });

  it("casts the rank field from string to number", async () => {
    getLeaderboard.mockResolvedValue([
      { rank: "5", player_id: "LUD-005", full_name: "Carol", avatar: null, wins: 3 },
    ]);

    const res = makeRes();
    await getLeaderboardHandler(makeReq(), res);

    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0] as {
      data: { leaderboard: { rank: unknown }[] };
    };
    expect(body.data.leaderboard[0]?.rank).toBe(5);
    expect(typeof body.data.leaderboard[0]?.rank).toBe("number");
  });

  it("returns 500 when getLeaderboard throws", async () => {
    getLeaderboard.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getLeaderboardHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
