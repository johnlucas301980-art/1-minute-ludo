import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import {
  createUser,
  deleteRefreshToken,
  deleteRefreshTokensByUser,
  findByEmail,
  findByEmailOrMobile,
  findById,
  findByMobile,
  findRefreshToken,
  saveRefreshToken,
  updateLastLogin,
  updatePasswordById,
  type UserRow,
} from "./user.service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeUserRow(overrides: Partial<UserRow> = {}): UserRow {
  return {
    id: "user-1",
    player_id: "player-1",
    full_name: "Alice",
    email: "alice@example.com",
    mobile: null,
    password_hash: "$2b$12$hash",
    country: null,
    avatar: null,
    is_verified: false,
    status: "active",
    last_login_at: null,
    created_at: new Date("2026-01-01T00:00:00Z"),
    updated_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// saveRefreshToken
// ---------------------------------------------------------------------------

describe("saveRefreshToken", () => {
  it("inserts the jti, user_id, and expires_at into refresh_tokens", async () => {
    pool.query.mockResolvedValue({ rowCount: 1 });
    const expiresAt = new Date("2026-02-01T00:00:00Z");

    await saveRefreshToken("user-1", "jti-abc", expiresAt);

    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO refresh_tokens/i);
    expect(params).toEqual(["jti-abc", "user-1", expiresAt]);
  });

  it("propagates database errors to the caller", async () => {
    pool.query.mockRejectedValue(new Error("connection refused"));

    await expect(saveRefreshToken("user-1", "jti-abc", new Date())).rejects.toThrow(
      "connection refused",
    );
  });
});

// ---------------------------------------------------------------------------
// findRefreshToken
// ---------------------------------------------------------------------------

describe("findRefreshToken", () => {
  it("returns the matching row when found", async () => {
    const row = { jti: "jti-abc", user_id: "user-1", expires_at: new Date() };
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await findRefreshToken("jti-abc");

    expect(result).toEqual(row);
    expect(pool.query).toHaveBeenCalledOnce();
    const [, params] = pool.query.mock.calls[0];
    expect(params).toEqual(["jti-abc"]);
  });

  it("returns null when no row matches", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await findRefreshToken("jti-missing");

    expect(result).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// deleteRefreshToken
// ---------------------------------------------------------------------------

describe("deleteRefreshToken", () => {
  it("deletes by jti scoped to the owner user_id", async () => {
    pool.query.mockResolvedValue({ rowCount: 1 });

    await deleteRefreshToken("jti-abc", "user-1");

    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/DELETE FROM refresh_tokens/i);
    expect(params).toEqual(["jti-abc", "user-1"]);
  });

  it("resolves without error when the token does not exist", async () => {
    pool.query.mockResolvedValue({ rowCount: 0 });

    await expect(deleteRefreshToken("jti-missing", "user-1")).resolves.toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// deleteRefreshTokensByUser
// ---------------------------------------------------------------------------

describe("deleteRefreshTokensByUser", () => {
  it("deletes all tokens for the given user", async () => {
    pool.query.mockResolvedValue({ rowCount: 3 });

    await deleteRefreshTokensByUser("user-1");

    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/DELETE FROM refresh_tokens/i);
    expect(params).toEqual(["user-1"]);
  });

  it("resolves without error when the user has no tokens", async () => {
    pool.query.mockResolvedValue({ rowCount: 0 });

    await expect(deleteRefreshTokensByUser("user-no-tokens")).resolves.toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// findByEmailOrMobile
// ---------------------------------------------------------------------------

describe("findByEmailOrMobile", () => {
  it("uses an email query when the identifier contains '@'", async () => {
    const user = makeUserRow();
    pool.query.mockResolvedValue({ rows: [user] });

    const result = await findByEmailOrMobile("alice@example.com");

    expect(result).toEqual(user);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/lower\(email\)/i);
    expect(params).toEqual(["alice@example.com"]);
  });

  it("uses a mobile query when the identifier has no '@'", async () => {
    const user = makeUserRow({ email: null, mobile: "+1234567890" });
    pool.query.mockResolvedValue({ rows: [user] });

    const result = await findByEmailOrMobile("+1234567890");

    expect(result).toEqual(user);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/mobile/i);
    expect(sql).not.toMatch(/lower\(email\)/i);
    expect(params).toEqual(["+1234567890"]);
  });

  it("returns null when no user matches the identifier", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await findByEmailOrMobile("unknown@example.com");

    expect(result).toBeNull();
  });

  it("treats any identifier with '@' as email regardless of position", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await findByEmailOrMobile("user@domain.co.uk");

    const [sql] = pool.query.mock.calls[0];
    expect(sql).toMatch(/lower\(email\)/i);
  });
});

// ---------------------------------------------------------------------------
// updateLastLogin
// ---------------------------------------------------------------------------

describe("updateLastLogin", () => {
  it("updates last_login_at for the given user id", async () => {
    pool.query.mockResolvedValue({ rowCount: 1 });

    await updateLastLogin("user-1");

    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/last_login_at/i);
    expect(params).toEqual(["user-1"]);
  });

  it("propagates database errors to the caller", async () => {
    pool.query.mockRejectedValue(new Error("deadlock detected"));

    await expect(updateLastLogin("user-1")).rejects.toThrow("deadlock detected");
  });
});

// ---------------------------------------------------------------------------
// findById
// ---------------------------------------------------------------------------

describe("findById", () => {
  it("returns the user row when the id is found", async () => {
    const user = makeUserRow();
    pool.query.mockResolvedValue({ rows: [user] });

    const result = await findById("user-1");

    expect(result).toEqual(user);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/WHERE id = \$1/i);
    expect(params).toEqual(["user-1"]);
  });

  it("returns null when no user matches the id", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await findById("unknown-id");

    expect(result).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// findByEmail
// ---------------------------------------------------------------------------

describe("findByEmail", () => {
  it("returns the user row for a matching email", async () => {
    const user = makeUserRow();
    pool.query.mockResolvedValue({ rows: [user] });

    const result = await findByEmail("alice@example.com");

    expect(result).toEqual(user);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/lower\(email\)/i);
    expect(params).toEqual(["alice@example.com"]);
  });

  it("passes the original case to the query so lower() handles normalisation", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await findByEmail("ALICE@EXAMPLE.COM");

    const [, params] = pool.query.mock.calls[0];
    expect(params).toEqual(["ALICE@EXAMPLE.COM"]);
  });

  it("returns null when no user has that email", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await findByEmail("nobody@example.com");

    expect(result).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// findByMobile
// ---------------------------------------------------------------------------

describe("findByMobile", () => {
  it("returns the user row for a matching mobile number", async () => {
    const user = makeUserRow({ email: null, mobile: "+1234567890" });
    pool.query.mockResolvedValue({ rows: [user] });

    const result = await findByMobile("+1234567890");

    expect(result).toEqual(user);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/mobile = \$1/i);
    expect(params).toEqual(["+1234567890"]);
  });

  it("returns null when no user has that mobile number", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await findByMobile("+0000000000");

    expect(result).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// updatePasswordById
// ---------------------------------------------------------------------------

describe("updatePasswordById", () => {
  it("returns true when a row was updated", async () => {
    pool.query.mockResolvedValue({ rowCount: 1 });

    const result = await updatePasswordById("user-1", "$2b$12$newhash");

    expect(result).toBe(true);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/password_hash/i);
    expect(params).toEqual(["$2b$12$newhash", "user-1"]);
  });

  it("returns false when no row matched (user not found)", async () => {
    pool.query.mockResolvedValue({ rowCount: 0 });

    const result = await updatePasswordById("nonexistent-user", "$2b$12$newhash");

    expect(result).toBe(false);
  });

  it("handles a null rowCount by treating it as zero", async () => {
    pool.query.mockResolvedValue({ rowCount: null });

    const result = await updatePasswordById("user-1", "$2b$12$newhash");

    expect(result).toBe(false);
  });

  it("propagates database errors to the caller", async () => {
    pool.query.mockRejectedValue(new Error("connection refused"));

    await expect(updatePasswordById("user-1", "$2b$12$newhash")).rejects.toThrow(
      "connection refused",
    );
  });
});

// ---------------------------------------------------------------------------
// createUser
// ---------------------------------------------------------------------------

describe("createUser", () => {
  it("inserts the user and returns the created row", async () => {
    const created = {
      id: "user-new",
      player_id: "player-new",
      full_name: "Bob",
      email: "bob@example.com",
      mobile: null,
      status: "active",
      created_at: new Date("2026-01-02T00:00:00Z"),
    };
    pool.query.mockResolvedValue({ rows: [created] });

    const result = await createUser({
      full_name: "Bob",
      email: "bob@example.com",
      mobile: null,
      password_hash: "$2b$12$bobhash",
      country: "US",
    });

    expect(result).toEqual(created);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO users/i);
    expect(params).toEqual(["Bob", "bob@example.com", null, "$2b$12$bobhash", "US"]);
  });

  it("coerces undefined email, mobile, and country to null", async () => {
    const created = {
      id: "user-new",
      player_id: "player-new",
      full_name: "Carol",
      email: null,
      mobile: null,
      status: "active",
      created_at: new Date(),
    };
    pool.query.mockResolvedValue({ rows: [created] });

    await createUser({
      full_name: "Carol",
      email: null,
      mobile: null,
      password_hash: "$2b$12$carolhash",
      // country intentionally omitted — service must default to null
    });

    const [, params] = pool.query.mock.calls[0];
    // [full_name, email, mobile, password_hash, country]
    expect(params[1]).toBeNull(); // email
    expect(params[2]).toBeNull(); // mobile
    expect(params[4]).toBeNull(); // country
  });

  it("propagates database errors to the caller", async () => {
    pool.query.mockRejectedValue(new Error("unique constraint violation"));

    await expect(
      createUser({
        full_name: "Dave",
        email: "dave@example.com",
        mobile: null,
        password_hash: "$2b$12$davehash",
      }),
    ).rejects.toThrow("unique constraint violation");
  });
});
