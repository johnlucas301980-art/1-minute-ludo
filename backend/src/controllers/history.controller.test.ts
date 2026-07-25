import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const { getMatchHistory } = vi.hoisted(() => ({
  getMatchHistory: vi.fn(),
}));

vi.mock("../services/history.service.js", () => ({ getMatchHistory }));
vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import { getHistory } from "./history.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq(query: Record<string, string> = {}, userId = "user-1"): Request {
  return {
    log: { error: vi.fn() },
    user: { id: userId },
    query,
  } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

/** A minimal match history row returned by the service. */
function makeRow(overrides = {}) {
  return {
    match_id: "match-1",
    room_code: "ABCD",
    mode: "classic",
    started_at: new Date("2026-01-01T00:00:00Z"),
    finished_at: new Date("2026-01-01T00:01:00Z"),
    result: "win",
    earned_points: "10.00",
    entry_points: "5.00",
    opponent_player_id: "LUD-002",
    opponent_full_name: "Bob",
    opponent_avatar: null,
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("getHistory", () => {
  it("returns 200 with serialized match rows using default pagination", async () => {
    const row = makeRow();
    getMatchHistory.mockResolvedValue({ rows: [row], total: 1 });

    const res = makeRes();
    await getHistory(makeReq(), res);

    expect(getMatchHistory).toHaveBeenCalledWith("user-1", 20, 0);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        matches: [
          {
            match_id: row.match_id,
            room_code: row.room_code,
            mode: row.mode,
            started_at: row.started_at,
            finished_at: row.finished_at,
            result: row.result,
            earned_points: 10,
            entry_points: 5,
            opponent: {
              player_id: row.opponent_player_id,
              full_name: row.opponent_full_name,
              avatar: row.opponent_avatar,
            },
          },
        ],
        pagination: { total: 1, limit: 20, offset: 0 },
      },
    });
  });

  it("forwards valid limit and offset query params to the service", async () => {
    getMatchHistory.mockResolvedValue({ rows: [], total: 0 });

    await getHistory(makeReq({ limit: "10", offset: "20" }), makeRes());

    expect(getMatchHistory).toHaveBeenCalledWith("user-1", 10, 20);
  });

  it("returns 400 when limit is below the minimum (1)", async () => {
    const res = makeRes();
    await getHistory(makeReq({ limit: "0" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false }),
    );
    expect(getMatchHistory).not.toHaveBeenCalled();
  });

  it("returns 400 when limit exceeds the maximum (100)", async () => {
    const res = makeRes();
    await getHistory(makeReq({ limit: "101" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getMatchHistory).not.toHaveBeenCalled();
  });

  it("falls back to default limit when limit is non-numeric", async () => {
    getMatchHistory.mockResolvedValue({ rows: [], total: 0 });

    await getHistory(makeReq({ limit: "abc" }), makeRes());

    expect(getMatchHistory).toHaveBeenCalledWith("user-1", 20, 0);
  });

  it("clamps negative offset to 0 silently", async () => {
    getMatchHistory.mockResolvedValue({ rows: [], total: 0 });

    await getHistory(makeReq({ offset: "-5" }), makeRes());

    expect(getMatchHistory).toHaveBeenCalledWith("user-1", 20, 0);
  });

  it("converts earned_points and entry_points from string to float", async () => {
    getMatchHistory.mockResolvedValue({
      rows: [makeRow({ earned_points: "12.50", entry_points: "6.25" })],
      total: 1,
    });

    const res = makeRes();
    await getHistory(makeReq(), res);

    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0] as {
      data: { matches: { earned_points: number; entry_points: number }[] };
    };
    expect(body.data.matches[0]?.earned_points).toBe(12.5);
    expect(body.data.matches[0]?.entry_points).toBe(6.25);
  });

  it("returns 500 when getMatchHistory throws", async () => {
    getMatchHistory.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getHistory(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
