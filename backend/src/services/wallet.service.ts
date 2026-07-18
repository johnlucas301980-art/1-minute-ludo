/**
 * Wallet service — all direct database access for wallets and transactions.
 * Controllers must never query the database directly; they call this module.
 */

import { pool } from "../db/index";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** A player's wallet row as returned by the database. */
export interface WalletRow {
  id: string;
  user_id: string;
  /** String representation of NUMERIC — use parseFloat where a number is needed. */
  points: string;
  total_deposit: string;
  total_withdraw: string;
  updated_at: Date;
}

/** A single ledger entry as returned by the database. */
export interface TransactionRow {
  id: string;
  user_id: string;
  /** One of: deposit | withdraw | reward | entry_fee | refund */
  type: string;
  /** String representation of NUMERIC — use parseFloat where a number is needed. */
  amount: string;
  /** One of: pending | completed | failed | reversed */
  status: string;
  reference: string | null;
  created_at: Date;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/**
 * Return the wallet row for the given user, or null if none exists yet.
 */
export async function findWalletByUserId(userId: string): Promise<WalletRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<WalletRow>(
    `SELECT id, user_id, points, total_deposit, total_withdraw, updated_at
     FROM wallets
     WHERE user_id = $1
     LIMIT 1`,
    [userId],
  );
  return rows[0] ?? null;
}

/**
 * Return the wallet for the given user, creating a zero-balance wallet if one
 * does not yet exist.  The INSERT … ON CONFLICT upsert is atomic and safe
 * against concurrent calls.
 */
export async function findOrCreateWallet(userId: string): Promise<WalletRow> {
  if (!pool) throw new Error("Database is not available.");

  // ON CONFLICT DO UPDATE with a no-op SET ensures RETURNING always fires,
  // whether the row was just inserted or already existed.
  const { rows } = await pool.query<WalletRow>(
    `INSERT INTO wallets (user_id)
     VALUES ($1)
     ON CONFLICT (user_id) DO UPDATE
       SET updated_at = wallets.updated_at
     RETURNING id, user_id, points, total_deposit, total_withdraw, updated_at`,
    [userId],
  );
  return rows[0]!;
}

/**
 * Return a paginated list of transactions for the given user, ordered newest
 * first.
 *
 * @param userId  - UUID of the authenticated player.
 * @param limit   - Maximum rows to return (1–100, default 20).
 * @param offset  - Number of rows to skip for pagination (default 0).
 */
export async function getTransactions(
  userId: string,
  limit = 20,
  offset = 0,
): Promise<TransactionRow[]> {
  if (!pool) return [];
  const { rows } = await pool.query<TransactionRow>(
    `SELECT id, user_id, type, amount, status, reference, created_at
     FROM transactions
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset],
  );
  return rows;
}
