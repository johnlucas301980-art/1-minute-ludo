/**
 * Profile service — direct database access for player profile reads and updates.
 * Controllers must never query the database directly; they call this module.
 */

import { pool } from "../db/index";
import type { UserRow } from "./user.service";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Columns exposed to the client — never includes password_hash or google_id. */
export type ProfileRow = Pick<
  UserRow,
  | "id"
  | "player_id"
  | "full_name"
  | "email"
  | "mobile"
  | "country"
  | "avatar"
  | "status"
  | "created_at"
  | "updated_at"
>;

export interface UpdateProfileInput {
  full_name?: string;
  country?: string | null;
  avatar?: string | null;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/**
 * Return a safe profile projection for the given user id.
 * Returns null when the user does not exist.
 */
export async function findProfileById(id: string): Promise<ProfileRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<ProfileRow>(
    `SELECT id, player_id, full_name, email, mobile, country, avatar,
            status, created_at, updated_at
     FROM users
     WHERE id = $1
     LIMIT 1`,
    [id],
  );
  return rows[0] ?? null;
}

/**
 * Update mutable profile fields for the given user id.
 * Only fields explicitly included in `input` are changed.
 * The updated_at column is maintained automatically by the DB trigger.
 * Returns the updated profile row, or null if the user was not found.
 */
export async function updateProfileById(
  id: string,
  input: UpdateProfileInput,
): Promise<ProfileRow | null> {
  if (!pool) throw new Error("Database is not available.");

  // Build a dynamic SET clause from only the provided fields
  const setClauses: string[] = [];
  const values: unknown[] = [];

  if (input.full_name !== undefined) {
    values.push(input.full_name);
    setClauses.push(`full_name = $${values.length}`);
  }
  if (input.country !== undefined) {
    values.push(input.country);
    setClauses.push(`country = $${values.length}`);
  }
  if (input.avatar !== undefined) {
    values.push(input.avatar);
    setClauses.push(`avatar = $${values.length}`);
  }

  // If no fields were supplied, just return the current profile
  if (setClauses.length === 0) return findProfileById(id);

  values.push(id);
  const { rows } = await pool.query<ProfileRow>(
    `UPDATE users
     SET ${setClauses.join(", ")}
     WHERE id = $${values.length}
     RETURNING id, player_id, full_name, email, mobile, country, avatar,
               status, created_at, updated_at`,
    values,
  );
  return rows[0] ?? null;
}
