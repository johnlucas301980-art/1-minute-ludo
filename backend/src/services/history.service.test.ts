import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import {
  getMatchHistory,
  type MatchHistoryRow,
} from "./history.service.js";

function makeHistoryRow(overrides: Partial<MatchHistoryRow> = {}): MatchHistoryRow {
  return {
    match_id: "match-1",
    room_code: "ABC123",
    mode: "random",
    started_at: new Date("2026-01-01T00:00:00Z"),
    finished_at: new Date("2026-01-01T00:01:00Z"),
    result: "win",
    earned_points: "25.00",
    entry_points: "10.00",
    opponent_player_id: "LUD-000002",
    opponent_full_name: "Bob",
    opponent_avatar: null,
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

describe("getMatchHistory", () => {
  it("returns the total and paginated completed match rows", async () => {
    const rows = [
      makeHistoryRow(),
      makeHistoryRow({
        match_id: "match-2",
        result: "loss",
        opponent_player_id: "LUD-000003",
        opponent_full_name: "Carol",
        opponent_avatar: "https://example.com/carol.png",
      }),
    ];
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "7" }] })
      .mockResolvedValueOnce({ rows });

    const result = await getMatchHistory("user-1", 20, 40);

    expect(result).toEqual({ rows, total: 7 });
    expect(pool.query).toHaveBeenCalledTimes(2);
    expect(pool.query.mock.calls[0][1]).toEqual(["user-1"]);
    expect(pool.query.mock.calls[1][1]).toEqual(["user-1", 20, 40]);
  });

  it("queries only completed matches and orders history newest first", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [makeHistoryRow()] });

    await getMatchHistory("user-1", 10, 0);

    const [countSql] = pool.query.mock.calls[0];
    const [rowsSql] = pool.query.mock.calls[1];
    expect(countSql).toMatch(/m\.status\s*=\s*'finished'/i);
    expect(rowsSql).toMatch(/m\.status\s*=\s*'finished'/i);
    expect(rowsSql).toMatch(/ORDER BY m\.finished_at DESC/i);
  });

  it("returns an empty page without loading match rows when there are no matches", async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ total: "0" }] });

    await expect(getMatchHistory("user-1", 20, 0)).resolves.toEqual({
      rows: [],
      total: 0,
    });
    expect(pool.query).toHaveBeenCalledOnce();
  });

  it("defaults a missing count row to zero", async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    await expect(getMatchHistory("user-1", 20, 0)).resolves.toEqual({
      rows: [],
      total: 0,
    });
    expect(pool.query).toHaveBeenCalledOnce();
  });

  it("preserves nullable timestamps and opponent avatar values from the database", async () => {
    const row = makeHistoryRow({
      started_at: null,
      finished_at: null,
      opponent_avatar: null,
    });
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [row] });

    const result = await getMatchHistory("user-1", 1, 2);

    expect(result.rows[0]).toEqual(row);
    expect(result.rows[0]?.started_at).toBeNull();
    expect(result.rows[0]?.finished_at).toBeNull();
    expect(result.rows[0]?.opponent_avatar).toBeNull();
  });

  it("propagates a count query error", async () => {
    pool.query.mockRejectedValueOnce(new Error("count failed"));

    await expect(getMatchHistory("user-1", 20, 0)).rejects.toThrow("count failed");
  });

  it("propagates a paginated rows query error", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockRejectedValueOnce(new Error("history query failed"));

    await expect(getMatchHistory("user-1", 20, 0)).rejects.toThrow("history query failed");
  });
});