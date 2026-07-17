/**
 * User service — all direct database access for the users table.
 * Controllers must never query the database directly; they call this module.
 */

import { pool } from "../db/index";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface CreateUserInput {
  full_name: string;
  email: string | null;
  mobile: string | null;
  password_hash: string;
  country?: string | null;
}

export interface UserRow {
  id: string;
  player_id: string;
  full_name: string;
  email: string | null;
  mobile: string | null;
  password_hash: string;
  country: string | null;
  avatar: string | null;
  is_verified: boolean;
  status: string;
  last_login_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Refresh token queries
// ---------------------------------------------------------------------------

/**
 * Persist a refresh token's ID (jti) for later revocation checks.
 * The full token stays on the client — only its ID is stored here.
 */
export async function saveRefreshToken(
  userId: string,
  jti: string,
  expiresAt: Date,
): Promise<void> {
  if (!pool) throw new Error("Database is not available.");
  await pool.query(
    `INSERT INTO refresh_tokens (jti, user_id, expires_at)
     VALUES ($1, $2, $3)`,
    [jti, userId, expiresAt],
  );
}

/**
 * Look up a refresh token row by its jti.
 * Returns null if not found (revoked or never issued).
 */
export async function findRefreshToken(
  jti: string,
): Promise<{ jti: string; user_id: string; expires_at: Date } | null> {
  if (!pool) return null;
  const { rows } = await pool.query<{ jti: string; user_id: string; expires_at: Date }>(
    "SELECT jti, user_id, expires_at FROM refresh_tokens WHERE jti = $1 LIMIT 1",
    [jti],
  );
  return rows[0] ?? null;
}

/**
 * Delete a single refresh token by jti, scoped to the owner for safety.
 */
export async function deleteRefreshToken(jti: string, userId: string): Promise<void> {
  if (!pool) throw new Error("Database is not available.");
  await pool.query(
    "DELETE FROM refresh_tokens WHERE jti = $1 AND user_id = $2",
    [jti, userId],
  );
}

/**
 * Delete all refresh tokens for a user (logout from all devices).
 */
export async function deleteRefreshTokensByUser(userId: string): Promise<void> {
  if (!pool) throw new Error("Database is not available.");
  await pool.query("DELETE FROM refresh_tokens WHERE user_id = $1", [userId]);
}

/**
 * Find a user by either email (case-insensitive) or mobile number.
 * Identifier is treated as email when it contains '@', otherwise as mobile.
 * Returns the full row including password_hash — callers must never forward
 * this field to the client.
 */
export async function findByEmailOrMobile(identifier: string): Promise<UserRow | null> {
  if (!pool) return null;
  const isEmail = identifier.includes("@");
  const { rows } = await pool.query<UserRow>(
    isEmail
      ? "SELECT * FROM users WHERE lower(email) = lower($1) LIMIT 1"
      : "SELECT * FROM users WHERE mobile = $1 LIMIT 1",
    [identifier],
  );
  return rows[0] ?? null;
}

/**
 * Stamp last_login_at to now() for the given user id.
 * Throws on failure — callers must treat this as a hard error.
 */
export async function updateLastLogin(id: string): Promise<void> {
  if (!pool) throw new Error("Database is not available.");
  await pool.query("UPDATE users SET last_login_at = now() WHERE id = $1", [id]);
}

/**
 * Find a user by their UUID primary key.
 * Returns the full row including password_hash — callers must never forward it.
 */
export async function findById(id: string): Promise<UserRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<UserRow>(
    "SELECT * FROM users WHERE id = $1 LIMIT 1",
    [id],
  );
  return rows[0] ?? null;
}

/**
 * Find a user by their email address (case-insensitive).
 * Returns null when no match is found.
 */
export async function findByEmail(email: string): Promise<UserRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<UserRow>(
    "SELECT * FROM users WHERE lower(email) = lower($1) LIMIT 1",
    [email],
  );
  return rows[0] ?? null;
}

/**
 * Find a user by their mobile number.
 * Returns null when no match is found.
 */
export async function findByMobile(mobile: string): Promise<UserRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<UserRow>(
    "SELECT * FROM users WHERE mobile = $1 LIMIT 1",
    [mobile],
  );
  return rows[0] ?? null;
}

/**
 * Update the password hash for the given user id.
 * Returns true if a row was updated, false if the user was not found.
 */
export async function updatePasswordById(
  id: string,
  newPasswordHash: string,
): Promise<boolean> {
  if (!pool) throw new Error("Database is not available.");
  const { rowCount } = await pool.query(
    "UPDATE users SET password_hash = $1 WHERE id = $2",
    [newPasswordHash, id],
  );
  return (rowCount ?? 0) > 0;
}

/**
 * Insert a new user row.
 * `player_id` is auto-generated by the database trigger when not supplied.
 * Returns the newly created row (without password_hash).
 */
export async function createUser(
  input: CreateUserInput,
): Promise<Pick<UserRow, "id" | "player_id" | "full_name" | "email" | "mobile" | "status" | "created_at">> {
  if (!pool) {
    throw new Error("Database is not available.");
  }

  const { rows } = await pool.query<Pick<UserRow, "id" | "player_id" | "full_name" | "email" | "mobile" | "status" | "created_at">>(
    `INSERT INTO users (full_name, email, mobile, password_hash, country)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, player_id, full_name, email, mobile, status, created_at`,
    [
      input.full_name,
      input.email ?? null,
      input.mobile ?? null,
      input.password_hash,
      input.country ?? null,
    ],
  );

  return rows[0]!;
}
