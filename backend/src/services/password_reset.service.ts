/**
 * Password reset service — all database access for password_reset_otps.
 * Controllers must never query the database directly; they call this module.
 */

import { pool } from "../db/index";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** OTP is valid for this many minutes after creation. */
export const OTP_TTL_MINUTES = 15;

/** Maximum OTP requests per user per rolling hour window. */
export const MAX_REQUESTS_PER_HOUR = 3;

/** Number of failed verify attempts allowed before the OTP is invalidated. */
export const MAX_ATTEMPTS = 5;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface OtpRow {
  id: string;
  user_id: string;
  otp_hash: string;
  attempts: number;
  expires_at: Date;
  used_at: Date | null;
  created_at: Date;
}

// ---------------------------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------------------------

/**
 * Count OTP rows created for this user in the last hour.
 * Called before inserting a new row so the count is accurate.
 */
export async function countRecentOtpRequests(userId: string): Promise<number> {
  if (!pool) return 0;
  const { rows } = await pool.query<{ count: string }>(
    `SELECT count(*) AS count
     FROM password_reset_otps
     WHERE user_id = $1
       AND created_at > now() - interval '1 hour'`,
    [userId],
  );
  return Number(rows[0]?.count ?? 0);
}

// ---------------------------------------------------------------------------
// Create
// ---------------------------------------------------------------------------

/**
 * Insert a new OTP row and return its generated id.
 * The plaintext OTP is never stored — only its SHA-256 hash.
 */
export async function createOtp(userId: string, otpHash: string): Promise<string> {
  if (!pool) throw new Error("Database is not available.");
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1_000);
  const { rows } = await pool.query<{ id: string }>(
    `INSERT INTO password_reset_otps (user_id, otp_hash, expires_at)
     VALUES ($1, $2, $3)
     RETURNING id`,
    [userId, otpHash, expiresAt],
  );
  return rows[0]!.id;
}

// ---------------------------------------------------------------------------
// Verify (atomic attempt tracking)
// ---------------------------------------------------------------------------

/**
 * Atomically increment the attempt counter on the latest valid OTP for a user
 * and return the updated row.
 *
 * "Valid" means: not yet used and not yet expired.
 * Returns null when no such row exists (expired, already used, never created).
 *
 * Using a single UPDATE…RETURNING avoids a separate SELECT + UPDATE race.
 */
export async function incrementLatestOtpAttempt(userId: string): Promise<OtpRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<OtpRow>(
    `UPDATE password_reset_otps
     SET    attempts = attempts + 1
     WHERE  id = (
       SELECT id
       FROM   password_reset_otps
       WHERE  user_id  = $1
         AND  used_at  IS NULL
         AND  expires_at > now()
       ORDER  BY created_at DESC
       LIMIT  1
     )
     RETURNING id, user_id, otp_hash, attempts, expires_at, used_at, created_at`,
    [userId],
  );
  return rows[0] ?? null;
}

// ---------------------------------------------------------------------------
// Look up by id (confirm step)
// ---------------------------------------------------------------------------

/**
 * Fetch a specific OTP row by its primary key, scoped to the owner.
 * Returns null when not found.
 */
export async function findOtpById(otpId: string, userId: string): Promise<OtpRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<OtpRow>(
    `SELECT id, user_id, otp_hash, attempts, expires_at, used_at, created_at
     FROM   password_reset_otps
     WHERE  id      = $1
       AND  user_id = $2
     LIMIT  1`,
    [otpId, userId],
  );
  return rows[0] ?? null;
}

// ---------------------------------------------------------------------------
// Confirm (transactional)
// ---------------------------------------------------------------------------

/**
 * Apply the password reset atomically:
 *   1. Update users.password_hash.
 *   2. Mark the OTP row as used (sets used_at = now()).
 *   3. Delete all refresh tokens for the user (forces re-login on all devices).
 *
 * All three writes succeed or all are rolled back.
 */
export async function applyPasswordReset(
  userId: string,
  otpId: string,
  newPasswordHash: string,
): Promise<void> {
  if (!pool) throw new Error("Database is not available.");
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    await client.query(
      "UPDATE users SET password_hash = $1 WHERE id = $2",
      [newPasswordHash, userId],
    );

    await client.query(
      "UPDATE password_reset_otps SET used_at = now() WHERE id = $1 AND user_id = $2",
      [otpId, userId],
    );

    await client.query(
      "DELETE FROM refresh_tokens WHERE user_id = $1",
      [userId],
    );

    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// Cleanup
// ---------------------------------------------------------------------------

/**
 * Delete all expired OTP rows across all users.
 * Called on a scheduled interval (hourly) from the server entry point.
 * Returns the number of rows removed.
 */
export async function deleteExpiredOtps(): Promise<number> {
  if (!pool) return 0;
  const result = await pool.query(
    "DELETE FROM password_reset_otps WHERE expires_at < now()",
  );
  return result.rowCount ?? 0;
}
