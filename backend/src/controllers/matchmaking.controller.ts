/**
 * Matchmaking controller — Phase 5.1.
 *
 * REST surface is intentionally read-only:
 *   GET /api/match/queue/status — check whether the authenticated player is
 *                                 currently in the matchmaking queue.
 *
 * Queue join and leave are handled exclusively through Socket.IO
 * (find_match / leave_queue events) because those events carry the socketId
 * that is required to deliver the match_found notification in real-time.
 */

import type { Request, Response } from "express";
import { getEntry, isQueued, queueSize } from "../services/matchmaking.queue";

// ---------------------------------------------------------------------------
// GET /api/match/queue/status
// ---------------------------------------------------------------------------

/**
 * Return the authenticated player's current matchmaking queue status.
 *
 * Response (200):
 *   success: true
 *   data.inQueue    — true if the player is waiting for a match
 *   data.joinedAt   — ISO timestamp of when they joined (null when not queued)
 *   data.queueSize  — total number of players currently in the queue
 */
export function getQueueStatus(req: Request, res: Response): void {
  const userId = req.user!.id;
  const entry = getEntry(userId);

  res.status(200).json({
    success: true,
    data: {
      inQueue: isQueued(userId),
      joinedAt: entry ? entry.joinedAt.toISOString() : null,
      queueSize: queueSize(),
    },
  });
}
