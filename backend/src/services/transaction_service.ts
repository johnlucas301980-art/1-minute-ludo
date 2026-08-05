/**
 * Transaction Service — in-memory ledger engine.
 *
 * Records every wallet operation as an immutable entry.  Entries are never
 * modified or deleted after creation.  The ledger is ordered newest-first
 * when queried per player.
 *
 * No database.  No Firebase.  No payment gateway.  No UI.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** All supported transaction types. */
export type TransactionType =
  | "Recharge"
  | "EntryFee"
  | "WinReward"
  | "Refund"
  | "Withdrawal"
  | "AdminAdjustment";

/** An immutable ledger entry. */
export interface Transaction {
  /** Unique identifier for this transaction. */
  transactionId: string;
  /** Player this transaction belongs to. */
  playerId: string;
  /** Category of the wallet operation. */
  type: TransactionType;
  /** Absolute value of points moved (always positive). */
  amount: number;
  /** Player balance immediately before this transaction. */
  balanceBefore: number;
  /** Player balance immediately after this transaction. */
  balanceAfter: number;
  /** Wall-clock time the transaction was recorded. */
  createdAt: Date;
  /** Optional external reference (match ID, payment ID, admin note, etc.). */
  referenceId?: string;
}

/** Parameters required to record a new transaction. */
export interface CreateTransactionParams {
  playerId: string;
  type: TransactionType;
  amount: number;
  balanceBefore: number;
  balanceAfter: number;
  referenceId?: string;
}

// ---------------------------------------------------------------------------
// In-memory store
// ---------------------------------------------------------------------------

/** All transactions, keyed by transactionId for O(1) lookup. */
const store = new Map<string, Readonly<Transaction>>();

/** Per-player ordered list of transactionIds (oldest → newest). */
const playerIndex = new Map<string, string[]>();

/** Reset all ledger state — for test isolation only. */
export function _resetForTesting(): void {
  store.clear();
  playerIndex.clear();
}

// ---------------------------------------------------------------------------
// ID generation (injectable for tests via module-level override)
// ---------------------------------------------------------------------------

/** Generates a unique transaction ID.  Override in tests with vi.spyOn. */
export let generateId: () => string = () => crypto.randomUUID();

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Record a new ledger entry and return the immutable transaction object.
 *
 * The returned object is frozen — any attempt to mutate it will throw in
 * strict mode and silently fail otherwise.
 *
 * @param params - Fields describing the wallet operation.
 * @returns      The newly created, frozen {@link Transaction}.
 */
export function createTransaction(params: CreateTransactionParams): Readonly<Transaction> {
  const tx: Transaction = {
    transactionId: generateId(),
    playerId: params.playerId,
    type: params.type,
    amount: params.amount,
    balanceBefore: params.balanceBefore,
    balanceAfter: params.balanceAfter,
    createdAt: new Date(),
    referenceId: params.referenceId,
  };

  const frozen = Object.freeze(tx);
  store.set(frozen.transactionId, frozen);

  const ids = playerIndex.get(params.playerId) ?? [];
  ids.push(frozen.transactionId);
  playerIndex.set(params.playerId, ids);

  return frozen;
}

/**
 * Return all transactions for a player, sorted newest first.
 *
 * Returns an empty array for players with no history.  Each entry in the
 * returned array is the same frozen object stored in the ledger — callers
 * must not attempt to modify them.
 *
 * @param playerId - Unique player identifier.
 */
export function getPlayerTransactions(playerId: string): ReadonlyArray<Readonly<Transaction>> {
  const ids = playerIndex.get(playerId) ?? [];
  // Reverse a copy so the internal index (oldest → newest) is untouched.
  return ids.slice().reverse().map((id) => store.get(id)!);
}

/**
 * Look up a single transaction by its unique ID.
 *
 * @param transactionId - The ID returned by {@link createTransaction}.
 * @returns             The frozen {@link Transaction}, or `undefined` if not found.
 */
export function getTransactionById(
  transactionId: string,
): Readonly<Transaction> | undefined {
  return store.get(transactionId);
}
