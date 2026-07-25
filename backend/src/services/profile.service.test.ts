import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import {
  findProfileById,
  updateProfileById,
  type ProfileRow,
} from "./profile.service.js";

function makeProfile(overrides: Partial<ProfileRow> = {}): ProfileRow {
  return {
    id: "user-1",
    player_id: "LUD-000001",
    full_name: "Alice",
    email: "alice@example.com",
    mobile: "+1234567890",
    country: "US",
    avatar: null,
    status: "active",
    created_at: new Date("2026-01-01T00:00:00Z"),
    updated_at: new Date("2026-01-02T00:00:00Z"),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

describe("findProfileById", () => {
  it("returns the safe profile projection when the user exists", async () => {
    const profile = makeProfile();
    pool.query.mockResolvedValue({ rows: [profile] });

    await expect(findProfileById("user-1")).resolves.toEqual(profile);

    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/SELECT id, player_id, full_name, email, mobile, country, avatar/i);
    expect(sql).toMatch(/FROM users/i);
    expect(sql).toMatch(/WHERE id = \$1/i);
    expect(sql).not.toMatch(/password_hash|google_id/i);
    expect(params).toEqual(["user-1"]);
  });

  it("returns null when the profile does not exist", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(findProfileById("missing-user")).resolves.toBeNull();
  });

  it("propagates database errors", async () => {
    pool.query.mockRejectedValue(new Error("profile lookup failed"));

    await expect(findProfileById("user-1")).rejects.toThrow("profile lookup failed");
  });
});

describe("updateProfileById", () => {
  it("updates all supplied fields with ordered parameters", async () => {
    const profile = makeProfile({ full_name: "Alice Smith", country: "CA", avatar: "https://example.com/a.png" });
    pool.query.mockResolvedValue({ rows: [profile] });

    await expect(
      updateProfileById("user-1", {
        full_name: "Alice Smith",
        country: "CA",
        avatar: "https://example.com/a.png",
      }),
    ).resolves.toEqual(profile);

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/UPDATE users/i);
    expect(sql).toMatch(/full_name = \$1/i);
    expect(sql).toMatch(/country = \$2/i);
    expect(sql).toMatch(/avatar = \$3/i);
    expect(sql).toMatch(/WHERE id = \$4/i);
    expect(params).toEqual(["Alice Smith", "CA", "https://example.com/a.png", "user-1"]);
  });

  it("updates only the fields included in the input", async () => {
    pool.query.mockResolvedValue({ rows: [makeProfile({ country: null })] });

    await updateProfileById("user-1", { country: null });

    const [sql, params] = pool.query.mock.calls[0];
    const setClause = sql.match(/SET\s+(.+?)\s+WHERE/is)?.[1] ?? "";
    expect(setClause).toMatch(/country = \$1/i);
    expect(setClause).not.toMatch(/full_name|avatar/i);
    expect(params).toEqual([null, "user-1"]);
  });

  it("returns null when no user row is updated", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(updateProfileById("missing-user", { full_name: "Bob" })).resolves.toBeNull();
  });

  it("returns the current profile without an update query when no fields are supplied", async () => {
    const profile = makeProfile();
    pool.query.mockResolvedValue({ rows: [profile] });

    await expect(updateProfileById("user-1", {})).resolves.toEqual(profile);

    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/SELECT/i);
    expect(sql).not.toMatch(/^UPDATE/i);
    expect(params).toEqual(["user-1"]);
  });

  it("returns null when a no-op lookup finds no profile", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(updateProfileById("missing-user", {})).resolves.toBeNull();
    expect(pool.query).toHaveBeenCalledOnce();
  });

  it("propagates database errors from an update", async () => {
    pool.query.mockRejectedValue(new Error("profile update failed"));

    await expect(updateProfileById("user-1", { avatar: null })).rejects.toThrow(
      "profile update failed",
    );
  });
});