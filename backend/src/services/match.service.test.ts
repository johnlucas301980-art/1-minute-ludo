import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => {
  const client = {
    query: vi.fn(),
    release: vi.fn(),
  };
  const pool = {
    query: vi.fn(),
    connect: vi.fn().mockResolvedValue(client),
    _client: client,
  };
  return { pool };
});

vi.mock("../db/index", () => ({ pool }));

import {
  createMatch,
  findMatchById,
  type MatchPlayerRow,
  type MatchRow,
} from "./match.service";

const player1 = {
  userId: "user-1",
  playerId: "LUD-000001",
  fullName: "Alice",
  avatar: null,
  socketId: "socket-1",
  joinedAt: new Date("2026-01-01T00:00:00Z"),
};

const player2 = {
  userId: "user-2",
  playerId: "LUD-000002",
  fullName: "Bob",
  avatar: "https://example.com/bob.png",
  socketId: "socket-2",
  joinedAt: new Date("2026-01-01T00:00:01Z"),
};

function makeMatch(overrides: Partial<MatchRow> = {}): MatchRow {
  return {
    id: "match-1",
    room_code: "AAAAAA",
    mode: "random",
    status: "waiting",
    entry_points: "0",
    player_count: 2,
    winner_id: null,
    started_at: null,
    finished_at: null,
    created_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

function makePlayer(overrides: Partial<MatchPlayerRow> = {}): MatchPlayerRow {
  return {
    id: "match-player-1",
    match_id: "match-1",
    user_id: "user-1",
    color: "blue",
    final_rank: null,
    earned_points: "0",
    joined_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

function getClient() {
  return pool._client as {
    query: ReturnType<typeof vi.fn>;
    release: ReturnType<typeof vi.fn>;
  };
}

beforeEach(() => {
  vi.resetAllMocks();
  pool.connect.mockResolvedValue(pool._client);
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("createMatch", () => {
  it("creates a waiting match with two players in one transaction", async () => {
    const client = getClient();
    const match = makeMatch();
    const firstPlayer = makePlayer({ color: "blue" });
    const secondPlayer = makePlayer({
      id: "match-player-2",
      user_id: "user-2",
      color: "red",
      joined_at: new Date("2026-01-01T00:00:01Z"),
    });
    vi.spyOn(Math, "random").mockReturnValue(0);
    client.query
      .mockResolvedValueOnce({}) // BEGIN
      .mockResolvedValueOnce({ rows: [] }) // room code is available
      .mockResolvedValueOnce({ rows: [match] })
      .mockResolvedValueOnce({ rows: [firstPlayer] })
      .mockResolvedValueOnce({ rows: [secondPlayer] })
      .mockResolvedValueOnce({}); // COMMIT

    await expect(createMatch(player1, player2)).resolves.toEqual({
      match,
      players: [firstPlayer, secondPlayer],
    });

    expect(client.query).toHaveBeenCalledTimes(6);
    expect(client.query.mock.calls[1][1]).toEqual(["AAAAAA"]);
    expect(client.query.mock.calls[2][1]).toEqual(["AAAAAA"]);
    expect(client.query.mock.calls[3][1]).toEqual(["match-1", "user-1", "blue"]);
    expect(client.query.mock.calls[4][1]).toEqual(["match-1", "user-2", "red"]);
    expect(client.query.mock.calls[5][0]).toBe("COMMIT");
    expect(client.release).toHaveBeenCalledOnce();
  });

  it("retries occupied room codes and keeps the first available code", async () => {
    const client = getClient();
    const match = makeMatch({ room_code: "BBBBBB" });
    let randomCalls = 0;
    vi.spyOn(Math, "random").mockImplementation(() => {
      randomCalls += 1;
      return randomCalls <= 6 ? 0 : randomCalls === 7 ? 0.04 : 0.9;
    });
    client.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({ rows: [{ id: "existing-match" }] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [match] })
      .mockResolvedValueOnce({ rows: [makePlayer()] })
      .mockResolvedValueOnce({ rows: [makePlayer({ id: "match-player-2", user_id: "user-2" })] })
      .mockResolvedValueOnce({});

    await expect(createMatch(player1, player2)).resolves.toMatchObject({ match });

    expect(client.query.mock.calls[1][1][0]).toBe("AAAAAA");
    expect(client.query.mock.calls[2][1][0]).toMatch(/^[A-Z2-9]{6}$/);
    expect(client.query.mock.calls[3][0]).toMatch(/INSERT INTO matches/i);
  });

  it("rolls back after exhausting room-code attempts", async () => {
    const client = getClient();
    vi.spyOn(Math, "random").mockReturnValue(0);
    client.query.mockResolvedValueOnce({});
    for (let attempt = 0; attempt < 10; attempt++) {
      client.query.mockResolvedValueOnce({ rows: [{ id: "existing-match" }] });
    }
    client.query.mockResolvedValueOnce({});

    await expect(createMatch(player1, player2)).rejects.toThrow(
      "Failed to generate a unique room code after maximum attempts.",
    );

    expect(client.query).toHaveBeenCalledTimes(12);
    expect(client.query.mock.calls.at(-1)?.[0]).toBe("ROLLBACK");
    expect(client.release).toHaveBeenCalledOnce();
  });

  it("rolls back and releases the client when match creation fails", async () => {
    const client = getClient();
    const failure = new Error("match insert failed");
    vi.spyOn(Math, "random").mockReturnValue(0);
    client.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({ rows: [] })
      .mockRejectedValueOnce(failure)
      .mockResolvedValueOnce({});

    await expect(createMatch(player1, player2)).rejects.toThrow("match insert failed");

    expect(client.query.mock.calls.at(-1)?.[0]).toBe("ROLLBACK");
    expect(client.release).toHaveBeenCalledOnce();
  });
});

describe("findMatchById", () => {
  it("returns a match row scoped by its UUID", async () => {
    const match = makeMatch();
    pool.query.mockResolvedValue({ rows: [match] });

    await expect(findMatchById("match-1")).resolves.toEqual(match);

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/FROM matches/i);
    expect(sql).toMatch(/WHERE id = \$1/i);
    expect(params).toEqual(["match-1"]);
  });

  it("returns null when the match does not exist", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(findMatchById("missing-match")).resolves.toBeNull();
  });

  it("propagates database errors", async () => {
    pool.query.mockRejectedValue(new Error("match lookup failed"));

    await expect(findMatchById("match-1")).rejects.toThrow("match lookup failed");
  });
});