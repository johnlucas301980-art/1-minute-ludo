/**
 * Leaderboard service — Phase 8.4 (Leaderboard Backend).
 *
 * All direct database access for leaderboard data.
 * Controllers must never query the database directly; they call this module.
 */

import { pool } from "../db/index.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** A single entry in the leaderboard as returned by getLeaderboard. */
export interface LeaderboardRow {
  rank: number;
  player_id: string;
  full_name: string;
  avatar: string | null;
  wins: number;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/**
 * Compute and return the full leaderboard.
 *
 * Counts wins by tallying finished matches where the user is the winner.
 * Ordered by wins DESC, then full_name ASC.
 * Rank is assigned sequentially (ties share no special treatment — each row
 * gets its own sequential rank by the natural ordering).
 *
 * No VIEW, no migration, no new tables — computed directly from
 * matches, match_players, and users.
 */
export async function getLeaderboard(): Promise<LeaderboardRow[]> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<LeaderboardRow>(
    `SELECT
       ROW_NUMBER() OVER (ORDER BY COUNT(CASE WHEN m.winner_id = u.id THEN 1 END) DESC, u.full_name ASC) AS rank,
       u.player_id,
       u.full_name,
       u.avatar,
       COUNT(CASE WHEN m.winner_id = u.id THEN 1 END)::int AS wins
     FROM users u
     LEFT JOIN match_players mp ON mp.user_id = u.id
     LEFT JOIN matches m        ON m.id = mp.match_id AND m.status = 'finished'
     GROUP BY u.id, u.player_id, u.full_name, u.avatar
     ORDER BY wins DESC, u.full_name ASC`,
  );

  return rows;
}
