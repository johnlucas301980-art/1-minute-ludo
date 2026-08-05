/**
 * Settlement service — pure, stateless fee-settlement calculations.
 *
 * No database access; all functions are synchronous and referentially
 * transparent so they can be unit-tested without mocking.
 *
 * Supported player counts: 2 | 3 | 4
 * Platform fee:            0  (winner takes the entire pool)
 */

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Player counts the game supports. */
export const SUPPORTED_PLAYER_COUNTS = [2, 3, 4] as const;
export type SupportedPlayerCount = (typeof SUPPORTED_PLAYER_COUNTS)[number];

/** Platform fee rate — fixed at 0 for this version. */
export const PLATFORM_FEE_RATE = 0;

// ---------------------------------------------------------------------------
// Domain errors
// ---------------------------------------------------------------------------

/** Thrown when an unsupported player count is supplied. */
export class InvalidPlayerCountError extends Error {
  constructor(playerCount: number) {
    super(
      `Invalid player count: ${playerCount}. Supported counts are ${SUPPORTED_PLAYER_COUNTS.join(", ")}.`,
    );
    this.name = "InvalidPlayerCountError";
  }
}

/** Thrown when a non-positive entry fee is supplied. */
export class InvalidEntryFeeError extends Error {
  constructor(entryFee: number) {
    super(`Invalid entry fee: ${entryFee}. Entry fee must be greater than zero.`);
    this.name = "InvalidEntryFeeError";
  }
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * The result of a match-fee settlement calculation.
 *
 * All monetary values are in the same unit as `entryFee` (e.g. points).
 */
export interface SettlementResult {
  /** The per-player entry fee used as input. */
  entryFee: number;
  /** Number of players in the match. */
  playerCount: number;
  /** Sum of all entry fees: entryFee × playerCount. */
  totalPool: number;
  /** Platform fee deducted from the pool (always 0 in this version). */
  platformFee: number;
  /** Gross reward allocated to the winner before any deduction: totalPool − platformFee. */
  winnerReward: number;
  /** Net reward paid out to the winner: winnerReward − platformFee. */
  netReward: number;
}

// ---------------------------------------------------------------------------
// Core calculation
// ---------------------------------------------------------------------------

/**
 * Calculate the settlement for a completed match.
 *
 * @param entryFee    - Positive amount each player paid to enter.
 * @param playerCount - Number of players in the match (2, 3, or 4).
 * @returns           A {@link SettlementResult} describing how the pool is distributed.
 *
 * @throws {InvalidEntryFeeError}    when `entryFee` is zero or negative.
 * @throws {InvalidPlayerCountError} when `playerCount` is not 2, 3, or 4.
 */
export function settle(entryFee: number, playerCount: number): SettlementResult {
  if (entryFee <= 0) {
    throw new InvalidEntryFeeError(entryFee);
  }

  if (!(SUPPORTED_PLAYER_COUNTS as readonly number[]).includes(playerCount)) {
    throw new InvalidPlayerCountError(playerCount);
  }

  const totalPool = entryFee * playerCount;
  const platformFee = PLATFORM_FEE_RATE * totalPool; // always 0
  const winnerReward = totalPool - platformFee;
  const netReward = winnerReward - platformFee;

  return { entryFee, playerCount, totalPool, platformFee, winnerReward, netReward };
}
