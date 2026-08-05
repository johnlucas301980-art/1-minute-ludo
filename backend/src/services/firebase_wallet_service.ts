/**
 * Firebase Wallet Sync Service
 *
 * Synchronises the in-memory wallet (wallet.service.ts) with Firebase
 * Realtime Database.  All reads and writes go through the four public
 * functions below; nothing else touches Firebase directly.
 *
 * Rules
 * -----
 * - Never overwrites a newer balance: each document carries an `updatedAt`
 *   epoch-ms timestamp; syncWallet() compares it against the timestamp of
 *   the last local sync before deciding which direction to merge.
 * - createWalletIfMissing() is a no-op when the Firebase record already
 *   exists, so it is safe to call on every session start.
 * - No payment gateway, no transaction history, no rewards, no match logic.
 */

import { getDatabase } from "firebase-admin/database";

import {
  creditPlayer,
  debitPlayer,
  getBalance,
} from "./wallet.service.js";

// ---------------------------------------------------------------------------
// Firebase document shape
// ---------------------------------------------------------------------------

interface FirebaseWalletDoc {
  /** Current balance in points. */
  balance: number;
  /** Unix epoch milliseconds — set by the writer, used for conflict resolution. */
  updatedAt: number;
}

// ---------------------------------------------------------------------------
// Local sync-timestamp registry
//
// Tracks when each player's balance was last written to (or read from)
// Firebase.  Used by syncWallet() to decide which side is newer.
// ---------------------------------------------------------------------------

const localTimestamps = new Map<string, number>();

/**
 * Reset all local timestamps **and** the in-memory wallet state.
 * For test isolation only — never call in production code.
 */
export function _resetForTesting(): void {
  localTimestamps.clear();
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/** Return the Firebase Realtime Database reference for a player's wallet. */
function walletRef(playerId: string) {
  return getDatabase().ref(`wallets/${playerId}`);
}

/**
 * Reconcile the local balance with a value read from Firebase.
 * Adjusts the in-memory wallet by crediting or debiting the difference.
 */
function reconcileLocal(playerId: string, firebaseBalance: number): void {
  const local = getBalance(playerId);
  const diff = firebaseBalance - local;
  if (diff > 0) creditPlayer(playerId, diff);
  else if (diff < 0) debitPlayer(playerId, -diff);
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Load the player's wallet from Firebase into local memory.
 *
 * - If no Firebase record exists, the function returns without modifying
 *   local state.
 * - If a record exists, local balance is reconciled to match Firebase and
 *   the local sync timestamp is updated.
 *
 * @param playerId - Unique player identifier.
 */
export async function loadWallet(playerId: string): Promise<void> {
  const snapshot = await walletRef(playerId).once("value");
  if (!snapshot.exists()) return;

  const doc = snapshot.val() as FirebaseWalletDoc;
  reconcileLocal(playerId, doc.balance);
  localTimestamps.set(playerId, doc.updatedAt);
}

/**
 * Persist the player's current local balance to Firebase.
 *
 * Writes `{ balance, updatedAt: Date.now() }` to Firebase and records the
 * timestamp locally so future syncWallet() calls can compare correctly.
 *
 * @param playerId - Unique player identifier.
 */
export async function saveWallet(playerId: string): Promise<void> {
  const balance = getBalance(playerId);
  const now = Date.now();
  const doc: FirebaseWalletDoc = { balance, updatedAt: now };
  await walletRef(playerId).set(doc);
  localTimestamps.set(playerId, now);
}

/**
 * Create a Firebase wallet record for the player if one does not yet exist.
 *
 * If a record already exists, this function is a no-op (it never overwrites
 * an existing balance).  Otherwise it calls saveWallet() to persist the
 * current local balance (which defaults to 0 for new players).
 *
 * @param playerId - Unique player identifier.
 */
export async function createWalletIfMissing(playerId: string): Promise<void> {
  const snapshot = await walletRef(playerId).once("value");
  if (snapshot.exists()) return;
  await saveWallet(playerId);
}

/**
 * Bidirectionally synchronise local memory and Firebase, never overwriting
 * the newer balance.
 *
 * Decision logic:
 * 1. If Firebase has no record → save local to Firebase.
 * 2. If Firebase `updatedAt` is strictly newer than the local sync timestamp
 *    → load from Firebase (Firebase wins).
 * 3. Otherwise (local is newer or timestamps are equal) → save to Firebase
 *    (local wins).
 *
 * @param playerId - Unique player identifier.
 */
export async function syncWallet(playerId: string): Promise<void> {
  const snapshot = await walletRef(playerId).once("value");

  // Case 1: no Firebase record — push local state up
  if (!snapshot.exists()) {
    await saveWallet(playerId);
    return;
  }

  const doc = snapshot.val() as FirebaseWalletDoc;
  const localTs = localTimestamps.get(playerId) ?? 0;

  if (doc.updatedAt > localTs) {
    // Case 2: Firebase is newer — pull down
    reconcileLocal(playerId, doc.balance);
    localTimestamps.set(playerId, doc.updatedAt);
  } else {
    // Case 3: local is newer or equal — push up
    await saveWallet(playerId);
  }
}
