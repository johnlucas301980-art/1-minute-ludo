import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import {
  getLeaderboard,
  type LeaderboardRow,
} from "./leaderboard.service.js";

function makeRow(overrides: Partial<LeaderboardRow> = {}): LeaderboardRow {
  return {
    rank: 1,
    player_id: "LUD-000001",
    full_name: "Alice",
    avatar: null,
    wins: 12,
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

describe("getLeaderboard", () => {
  it("returns the rows provided by the database in order", async () => {
    const rows = [
      makeRow(),
      makeRow({
        rank: 2,
        player_id: "LUD-000002",
        full_name: "Bob",
        avatar: "https://example.com/bob.png",
        wins: 8,
      }),
    ];
    pool.query.mockResolvedValue({ rows });

    await expect(getLeaderboard()).resolves.toEqual(rows);
    expect(pool.query).toHaveBeenCalledOnce();
  });

  it("queries finished-match wins and orders by wins then player name", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await getLeaderboard();

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/FROM users u/i);
    expect(sql).toMatch(/m\.status = 'finished'/i);
    expect(sql).toMatch(/COUNT\(CASE WHEN m\.winner_id = u\.id THEN 1 END\)/i);
    expect(sql).toMatch(/ORDER BY wins DESC, u\.full_name ASC/i);
    expect(params).toBeUndefined();
  });

  it("returns an empty list when no users are present", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(getLeaderboard()).resolves.toEqual([]);
  });

  it("preserves nullable avatars and numeric leaderboard fields", async () => {
    const row = makeRow({
      rank: 3,
      avatar: null,
      wins: 0,
    });
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await getLeaderboard();

    expect(result).toEqual([row]);
    expect(result[0]).toMatchObject({ rank: 3, avatar: null, wins: 0 });
  });

  it("propagates database errors", async () => {
    pool.query.mockRejectedValue(new Error("leaderboard query failed"));

    await expect(getLeaderboard()).rejects.toThrow("leaderboard query failed");
  });
});