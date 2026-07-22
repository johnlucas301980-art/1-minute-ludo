/**
 * Leaderboard controller — Phase 8.4 (Leaderboard Backend).
 *
 * GET /api/leaderboard — return the ranked leaderboard of all players,
 *                        ordered by wins DESC then full_name ASC.
 */

import type { Request, Response } from "express";
import { getLeaderboard } from "../services/leaderboard.service.js";

// ---------------------------------------------------------------------------
// GET /api/leaderboard
// ---------------------------------------------------------------------------

/**
 * Returns the global leaderboard.
 *
 * Response fields per entry:
 *   rank        — sequential position (1-based)
 *   player_id   — public player identifier
 *   full_name   — display name
 *   avatar      — avatar URL or null
 *   wins        — number of finished matches won
 */
export async function getLeaderboardHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const log = req.log;

  try {
    const rows = await getLeaderboard();

    res.status(200).json({
      success: true,
      data: {
        leaderboard: rows.map((row) => ({
          rank:      Number(row.rank),
          player_id: row.player_id,
          full_name: row.full_name,
          avatar:    row.avatar,
          wins:      row.wins,
        })),
      },
    });
  } catch (err) {
    log.error({ err }, "GetLeaderboard: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
