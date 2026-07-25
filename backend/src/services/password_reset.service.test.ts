import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => {
  const client = {
    query: vi.fn(),
    release: vi.fn(),
  };
  const pool = {
    query: vi.fn(),
    connect: vi.fn().mockResolvedValue(client),
    _client: client, // expose for per-test access
  };
  return { pool };
});

vi.mock("../db/index.js", () => ({ pool }));

import {
  MAX_ATTEMPTS,
  MAX_REQUESTS_PER_HOUR,
  OTP_TTL_MINUTES,
  applyPasswordReset,
  countRecentOtpRequests,
  createOtp,
  deleteExpiredOtps,
  findOtpById,
  incrementLatestOtpAttempt,
  type OtpRow,
} from "./password_reset.service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeOtpRow(overrides: Partial<OtpRow> = {}): OtpRow {
  return {
    id: "otp-1",
    user_id: "user-1",
    otp_hash: "abc123hash",
    attempts: 0,
    expires_at: new Date(Date.now() + 15 * 60 * 1_000),
    used_at: null,
    created_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

/** The pooled client exposed by the hoisted mock */
function getClient() {
  return pool._client as { query: ReturnType<typeof vi.fn>; release: ReturnType<typeof vi.fn> };
}

beforeEach(() => {
  vi.resetAllMocks();
  // Restore connect to always resolve the shared mock client
  pool.connect.mockResolvedValue(pool._client);
});

// ---------------------------------------------------------------------------
// Exported constants
// ---------------------------------------------------------------------------

describe("exported constants", () => {
  it("OTP_TTL_MINUTES is 15", () => {
    expect(OTP_TTL_MINUTES).toBe(15);
  });

  it("MAX_REQUESTS_PER_HOUR is 3", () => {
    expect(MAX_REQUESTS_PER_HOUR).toBe(3);
  });

  it("MAX_ATTEMPTS is 5", () => {
    expect(MAX_ATTEMPTS).toBe(5);
  });
});

// ---------------------------------------------------------------------------
// countRecentOtpRequests
// ---------------------------------------------------------------------------

describe("countRecentOtpRequests", () => {
  it("returns the numeric count from the database", async () => {
    pool.query.mockResolvedValue({ rows: [{ count: "2" }] });

    const result = await countRecentOtpRequests("user-1");

    expect(result).toBe(2);
    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/password_reset_otps/i);
    expect(params).toEqual(["user-1"]);
  });

  it("returns 0 when the user has no recent OTP requests", async () => {
    pool.query.mockResolvedValue({ rows: [{ count: "0" }] });

    const result = await countRecentOtpRequests("user-1");

    expect(result).toBe(0);
  });

  it("returns 0 when the query returns no rows", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await countRecentOtpRequests("user-1");

    expect(result).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// createOtp
// ---------------------------------------------------------------------------

describe("createOtp", () => {
  it("inserts a new OTP row and returns the generated id", async () => {
    pool.query.mockResolvedValue({ rows: [{ id: "otp-new" }] });

    const result = await createOtp("user-1", "sha256hash");

    expect(result).toBe("otp-new");
    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO password_reset_otps/i);
    expect(params[0]).toBe("user-1");
    expect(params[1]).toBe("sha256hash");
  });

  it("sets expires_at approximately OTP_TTL_MINUTES in the future", async () => {
    pool.query.mockResolvedValue({ rows: [{ id: "otp-new" }] });
    const before = Date.now();

    await createOtp("user-1", "sha256hash");

    const after = Date.now();
    const [, params] = pool.query.mock.calls[0];
    const expiresAt: Date = params[2];
    const expectedMin = before + OTP_TTL_MINUTES * 60 * 1_000;
    const expectedMax = after + OTP_TTL_MINUTES * 60 * 1_000;

    expect(expiresAt).toBeInstanceOf(Date);
    expect(expiresAt.getTime()).toBeGreaterThanOrEqual(expectedMin);
    expect(expiresAt.getTime()).toBeLessThanOrEqual(expectedMax);
  });

  it("propagates database errors to the caller", async () => {
    pool.query.mockRejectedValue(new Error("insert failed"));

    await expect(createOtp("user-1", "sha256hash")).rejects.toThrow("insert failed");
  });
});

// ---------------------------------------------------------------------------
// incrementLatestOtpAttempt
// ---------------------------------------------------------------------------

describe("incrementLatestOtpAttempt", () => {
  it("returns the updated OTP row when a valid OTP exists", async () => {
    const row = makeOtpRow({ attempts: 1 });
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await incrementLatestOtpAttempt("user-1");

    expect(result).toEqual(row);
    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/attempts = attempts \+ 1/i);
    expect(params).toEqual(["user-1"]);
  });

  it("returns null when no valid OTP exists for the user", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await incrementLatestOtpAttempt("user-1");

    expect(result).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// findOtpById
// ---------------------------------------------------------------------------

describe("findOtpById", () => {
  it("returns the OTP row when found for the given user", async () => {
    const row = makeOtpRow();
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await findOtpById("otp-1", "user-1");

    expect(result).toEqual(row);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/password_reset_otps/i);
    expect(params).toEqual(["otp-1", "user-1"]);
  });

  it("returns null when the OTP is not found", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await findOtpById("otp-missing", "user-1");

    expect(result).toBeNull();
  });

  it("returns null when the OTP belongs to a different user", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await findOtpById("otp-1", "other-user");

    expect(result).toBeNull();
    // Query must include user_id scope
    const [sql, params] = pool.query.mock.calls[0];
    expect(params).toContain("other-user");
    expect(sql).toMatch(/user_id/i);
  });
});

// ---------------------------------------------------------------------------
// applyPasswordReset
// ---------------------------------------------------------------------------

describe("applyPasswordReset", () => {
  it("executes BEGIN, three writes, and COMMIT in order", async () => {
    const client = getClient();
    client.query.mockResolvedValue({});

    await applyPasswordReset("user-1", "otp-1", "$2b$12$newhash");

    const calls: string[] = client.query.mock.calls.map((c: unknown[]) => c[0] as string);
    expect(calls[0]).toBe("BEGIN");
    expect(calls[1]).toMatch(/UPDATE users SET password_hash/i);
    expect(calls[2]).toMatch(/UPDATE password_reset_otps SET used_at/i);
    expect(calls[3]).toMatch(/DELETE FROM refresh_tokens/i);
    expect(calls[4]).toBe("COMMIT");
    expect(client.query).toHaveBeenCalledTimes(5);
  });

  it("passes the correct parameters to each write", async () => {
    const client = getClient();
    client.query.mockResolvedValue({});

    await applyPasswordReset("user-1", "otp-1", "$2b$12$newhash");

    const calls = client.query.mock.calls;
    // UPDATE users
    expect(calls[1][1]).toEqual(["$2b$12$newhash", "user-1"]);
    // UPDATE password_reset_otps
    expect(calls[2][1]).toEqual(["otp-1", "user-1"]);
    // DELETE FROM refresh_tokens
    expect(calls[3][1]).toEqual(["user-1"]);
  });

  it("rolls back and rethrows when a query fails mid-transaction", async () => {
    const client = getClient();
    client.query
      .mockResolvedValueOnce({}) // BEGIN
      .mockRejectedValueOnce(new Error("update failed")); // UPDATE users

    await expect(
      applyPasswordReset("user-1", "otp-1", "$2b$12$newhash"),
    ).rejects.toThrow("update failed");

    const calls: string[] = client.query.mock.calls.map((c: unknown[]) => c[0] as string);
    expect(calls).toContain("ROLLBACK");
    expect(calls).not.toContain("COMMIT");
  });

  it("always releases the client, even on failure", async () => {
    const client = getClient();
    client.query
      .mockResolvedValueOnce({}) // BEGIN
      .mockRejectedValueOnce(new Error("db error")); // UPDATE users

    await expect(
      applyPasswordReset("user-1", "otp-1", "$2b$12$newhash"),
    ).rejects.toThrow();

    expect(client.release).toHaveBeenCalledOnce();
  });

  it("releases the client after a successful transaction", async () => {
    const client = getClient();
    client.query.mockResolvedValue({});

    await applyPasswordReset("user-1", "otp-1", "$2b$12$newhash");

    expect(client.release).toHaveBeenCalledOnce();
  });
});

// ---------------------------------------------------------------------------
// deleteExpiredOtps
// ---------------------------------------------------------------------------

describe("deleteExpiredOtps", () => {
  it("returns the number of rows deleted", async () => {
    pool.query.mockResolvedValue({ rowCount: 7 });

    const result = await deleteExpiredOtps();

    expect(result).toBe(7);
    expect(pool.query).toHaveBeenCalledOnce();
    const [sql] = pool.query.mock.calls[0];
    expect(sql).toMatch(/DELETE FROM password_reset_otps/i);
    expect(sql).toMatch(/expires_at/i);
  });

  it("returns 0 when no rows were deleted", async () => {
    pool.query.mockResolvedValue({ rowCount: 0 });

    const result = await deleteExpiredOtps();

    expect(result).toBe(0);
  });

  it("returns 0 when rowCount is null", async () => {
    pool.query.mockResolvedValue({ rowCount: null });

    const result = await deleteExpiredOtps();

    expect(result).toBe(0);
  });
});
