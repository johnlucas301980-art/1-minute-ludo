/**
 * Wallet service — all direct database access for wallets and transactions.
 * Controllers must never query the database directly; they call this module.
 */

import { pool } from "../db/index";

// ---------------------------------------------------------------------------
// Domain errors
// ---------------------------------------------------------------------------

/** Thrown by withdrawPoints when the wallet balance is too low. */
export class InsufficientBalanceError extends Error {
  constructor(available: number, requested: number) {
    super(
      `Insufficient balance: available ${available}, requested ${requested}.`,
    );
    this.name = "InsufficientBalanceError";
  }
}

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

// ---------------------------------------------------------------------------
// Deposit
// ---------------------------------------------------------------------------

/** Result returned by depositPoints and withdrawPoints. */
export interface PaymentResult {
  wallet: WalletRow;
  transaction: TransactionRow;
}

/**
 * Credit `amount` points to the player's wallet.
 *
 * The entire operation runs inside a single PostgreSQL transaction so the
 * ledger and balance are always in sync:
 *   1. Ensure the wallet row exists (INSERT … ON CONFLICT upsert).
 *   2. INSERT a transaction row with status = 'pending'.
 *   3. UPDATE the wallet: points += amount, total_deposit += amount.
 *   4. UPDATE the transaction row to status = 'completed'.
 *
 * @param userId    - UUID of the authenticated player.
 * @param amount    - Positive number of points to credit.
 * @param reference - Optional external reference (e.g. payment gateway ID).
 */
export async function depositPoints(
  userId: string,
  amount: number,
  reference?: string,
): Promise<PaymentResult> {
  if (!pool) throw new Error("Database is not available.");

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // 1. Upsert wallet
    const { rows: walletRows } = await client.query<WalletRow>(
      `INSERT INTO wallets (user_id)
       VALUES ($1)
       ON CONFLICT (user_id) DO UPDATE
         SET updated_at = wallets.updated_at
       RETURNING id, user_id, points, total_deposit, total_withdraw, updated_at`,
      [userId],
    );
    const walletId = walletRows[0]!.id;

    // 2. Insert pending transaction
    const { rows: txPending } = await client.query<TransactionRow>(
      `INSERT INTO transactions (user_id, type, amount, status, reference)
       VALUES ($1, 'deposit', $2, 'pending', $3)
       RETURNING id, user_id, type, amount, status, reference, created_at`,
      [userId, amount, reference ?? null],
    );
    const txId = txPending[0]!.id;

    // 3. Credit the wallet
    const { rows: updatedWallet } = await client.query<WalletRow>(
      `UPDATE wallets
       SET points        = points        + $1,
           total_deposit = total_deposit + $1
       WHERE id = $2
       RETURNING id, user_id, points, total_deposit, total_withdraw, updated_at`,
      [amount, walletId],
    );

    // 4. Mark transaction completed
    const { rows: txCompleted } = await client.query<TransactionRow>(
      `UPDATE transactions
       SET status = 'completed'
       WHERE id = $1
       RETURNING id, user_id, type, amount, status, reference, created_at`,
      [txId],
    );

    await client.query("COMMIT");

    return {
      wallet: updatedWallet[0]!,
      transaction: txCompleted[0]!,
    };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// Withdraw
// ---------------------------------------------------------------------------

/**
 * Debit `amount` points from the player's wallet.
 *
 * The entire operation runs inside a single PostgreSQL transaction:
 *   1. Lock and fetch the current wallet row (SELECT … FOR UPDATE).
 *   2. Verify the balance is sufficient; throw InsufficientBalanceError if not.
 *   3. INSERT a transaction row with status = 'pending'.
 *   4. UPDATE the wallet: points -= amount, total_withdraw += amount.
 *      The DB CHECK (points >= 0) acts as a safety net.
 *   5. UPDATE the transaction row to status = 'completed'.
 *
 * @param userId    - UUID of the authenticated player.
 * @param amount    - Positive number of points to debit.
 * @param reference - Optional external reference.
 * @throws {InsufficientBalanceError} when balance < amount.
 */
export async function withdrawPoints(
  userId: string,
  amount: number,
  reference?: string,
): Promise<PaymentResult> {
  if (!pool) throw new Error("Database is not available.");

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // 1. Lock wallet row (upsert first so it always exists, then re-select for update)
    const { rows: walletRows } = await client.query<WalletRow>(
      `INSERT INTO wallets (user_id)
       VALUES ($1)
       ON CONFLICT (user_id) DO UPDATE
         SET updated_at = wallets.updated_at
       RETURNING id, user_id, points, total_deposit, total_withdraw, updated_at`,
      [userId],
    );
    const wallet = walletRows[0]!;

    // Lock the row for the rest of this transaction
    await client.query("SELECT id FROM wallets WHERE id = $1 FOR UPDATE", [
      wallet.id,
    ]);

    // 2. Check balance
    const available = parseFloat(wallet.points);
    if (available < amount) {
      await client.query("ROLLBACK");
      throw new InsufficientBalanceError(available, amount);
    }

    // 3. Insert pending transaction
    const { rows: txPending } = await client.query<TransactionRow>(
      `INSERT INTO transactions (user_id, type, amount, status, reference)
       VALUES ($1, 'withdraw', $2, 'pending', $3)
       RETURNING id, user_id, type, amount, status, reference, created_at`,
      [userId, amount, reference ?? null],
    );
    const txId = txPending[0]!.id;

    // 4. Debit the wallet
    const { rows: updatedWallet } = await client.query<WalletRow>(
      `UPDATE wallets
       SET points         = points         - $1,
           total_withdraw = total_withdraw + $1
       WHERE id = $2
       RETURNING id, user_id, points, total_deposit, total_withdraw, updated_at`,
      [amount, wallet.id],
    );

    // 5. Mark transaction completed
    const { rows: txCompleted } = await client.query<TransactionRow>(
      `UPDATE transactions
       SET status = 'completed'
       WHERE id = $1
       RETURNING id, user_id, type, amount, status, reference, created_at`,
      [txId],
    );

    await client.query("COMMIT");

    return {
      wallet: updatedWallet[0]!,
      transaction: txCompleted[0]!,
    };
  } catch (err) {
    // Only rollback if the error isn't InsufficientBalanceError
    // (we already rolled back in that branch)
    if (!(err instanceof InsufficientBalanceError)) {
      await client.query("ROLLBACK");
    }
    throw err;
  } finally {
    client.release();
  }
}
