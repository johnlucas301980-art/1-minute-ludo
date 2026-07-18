/**
 * Matchmaking queue — Phase 5.1.
 *
 * In-memory Map keyed by userId.  Node.js runs JS on a single thread, so
 * synchronous Map operations are inherently atomic — no external mutex is
 * required.
 *
 * Critical safety rule: REMOVE both players from the Map (synchronously)
 * BEFORE any `await` (the DB write).  This guarantees that no third player
 * can steal either slot while the database transaction is in flight.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface QueueEntry {
  userId: string;
  playerId: string;
  fullName: string;
  avatar: string | null;
  socketId: string;
  joinedAt: Date;
}

// ---------------------------------------------------------------------------
// Module-level queue state
// ---------------------------------------------------------------------------

/** The live matchmaking queue.  Never access this Map directly outside this
 *  module — always use the exported functions below. */
const _queue = new Map<string, QueueEntry>();

// ---------------------------------------------------------------------------
// Queue operations
// ---------------------------------------------------------------------------

/**
 * Add or replace a player's queue entry.
 * Replacing is used when the same player reconnects with a new socketId.
 */
export function enqueue(entry: QueueEntry): void {
  _queue.set(entry.userId, entry);
}

/**
 * Remove the player with the given userId from the queue.
 * Returns true if an entry was present and removed, false otherwise.
 */
export function dequeue(userId: string): boolean {
  return _queue.delete(userId);
}

/**
 * Return the queue entry for a player, or undefined if not present.
 */
export function getEntry(userId: string): QueueEntry | undefined {
  return _queue.get(userId);
}

/**
 * Whether the player is currently in the queue.
 */
export function isQueued(userId: string): boolean {
  return _queue.has(userId);
}

/**
 * Current number of players waiting in the queue.
 */
export function queueSize(): number {
  return _queue.size;
}

/**
 * Find and atomically remove the first waiting player who is NOT the given
 * user.  Returns undefined when no opponent is available.
 *
 * This function is synchronous and must be called before any async operation
 * so the removal is race-condition safe.
 */
export function dequeueOpponent(excludeUserId: string): QueueEntry | undefined {
  for (const [userId, entry] of _queue) {
    if (userId !== excludeUserId) {
      _queue.delete(userId);
      return entry;
    }
  }
  return undefined;
}

/**
 * Remove all queue entries whose joinedAt timestamp is older than maxAgeMs.
 * Returns the number of entries removed.
 *
 * Called by the periodic cleanup interval in index.ts.
 */
export function removeStaleEntries(maxAgeMs: number): number {
  const cutoff = Date.now() - maxAgeMs;
  let removed = 0;
  for (const [userId, entry] of _queue) {
    if (entry.joinedAt.getTime() < cutoff) {
      _queue.delete(userId);
      removed++;
    }
  }
  return removed;
}
