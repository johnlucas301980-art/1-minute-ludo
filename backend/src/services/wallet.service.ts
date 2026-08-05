/**
 * Wallet service — in-memory balance store.
 *
 * No database. No Firebase. No transaction history.
 * All state lives in a module-level Map and is reset when the process restarts.
 *
 * Responsibilities
 * ----------------
 * 1. Deposit points  — creditPlayer()
 * 2. Withdraw points — debitPlayer()
 * 3. Read balance    — getBalance()
 * 4. Apply settlement result — applySettlement()
 * 5. Validate balance / prevent negative balance — enforced inside debitPlayer()
 */

import { type SettlementResult } from "./settlement.service";

// ---------------------------------------------------------------------------
// Domain errors
// ---------------------------------------------------------------------------

/** Thrown by debitPlayer / applySettlement when funds are insufficient. */
export class InsufficientBalanceError extends Error {
  constructor(playerId: string, available: number, requested: number) {
    super(
      `Insufficient balance for player "${playerId}": available ${available}, requested ${requested}.`,
    );
    this.name = "InsufficientBalanceError";
  }
}

/** Thrown when a zero or negative amount is supplied to creditPlayer or debitPlayer. */
export class InvalidAmountError extends Error {
  constructor(amount: number) {
    super(`Invalid amount: ${amount}. Amount must be greater than zero.`);
    this.name = "InvalidAmountError";
  }
}

// ---------------------------------------------------------------------------
// In-memory store
// ---------------------------------------------------------------------------

/** Map<playerId, balance> — sole source of truth for all balances. */
const balances = new Map<string, number>();

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Reset all balances.  Exported for test isolation only — never call in
 * production code.
 */
export function _resetForTesting(): void {
  balances.clear();
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Return the current balance for `playerId`.
 * Returns 0 for players who have never been credited.
 */
export function getBalance(playerId: string): number {
  return balances.get(playerId) ?? 0;
}

/**
 * Credit `amount` points to `playerId`'s balance.
 *
 * @param playerId - Unique identifier for the player.
 * @param amount   - Positive number of points to add.
 * @returns        The new balance after crediting.
 *
 * @throws {InvalidAmountError} when `amount` is zero or negative.
 */
export function creditPlayer(playerId: string, amount: number): number {
  if (amount <= 0) throw new InvalidAmountError(amount);

  const current = getBalance(playerId);
  const next = current + amount;
  balances.set(playerId, next);
  return next;
}

/**
 * Debit `amount` points from `playerId`'s balance.
 *
 * @param playerId - Unique identifier for the player.
 * @param amount   - Positive number of points to remove.
 * @returns        The new balance after debiting.
 *
 * @throws {InvalidAmountError}        when `amount` is zero or negative.
 * @throws {InsufficientBalanceError}  when the player's balance < `amount`.
 */
export function debitPlayer(playerId: string, amount: number): number {
  if (amount <= 0) throw new InvalidAmountError(amount);

  const current = getBalance(playerId);
  if (current < amount) throw new InsufficientBalanceError(playerId, current, amount);

  const next = current - amount;
  balances.set(playerId, next);
  return next;
}

/**
 * Apply a completed match settlement.
 *
 * - Each loser is debited their `entryFee`.
 * - The winner is credited `netReward` (= totalPool when platformFee is 0).
 *
 * Losers are debited first; if any loser lacks sufficient balance the error is
 * thrown before the winner is credited, leaving all balances unchanged up to
 * that point.
 *
 * @param result      - The {@link SettlementResult} produced by settle().
 * @param winnerId    - Player ID of the match winner.
 * @param allPlayerIds - All player IDs in the match, including the winner.
 *
 * @throws {InsufficientBalanceError} when a loser cannot cover their entry fee.
 */
export function applySettlement(
  result: SettlementResult,
  winnerId: string,
  allPlayerIds: string[],
): void {
  const loserIds = allPlayerIds.filter((id) => id !== winnerId);

  for (const loserId of loserIds) {
    debitPlayer(loserId, result.entryFee);
  }

  creditPlayer(winnerId, result.netReward);
}
