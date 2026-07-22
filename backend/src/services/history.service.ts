/**
 * History service — Phase 8.1 (Match History Backend).
 *
 * All direct database access for match history.
 * Controllers must never query the database directly; they call this module.
 */

import { pool } from "../db/index.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** A single completed match as returned by getMatchHistory. */
export interface MatchHistoryRow {
  match_id: string;
  room_code: string;
  mode: string;
  started_at: Date | null;
  finished_at: Date | null;
  /** "win" when winner_id matches the requesting user; "loss" otherwise. */
  result: "win" | "loss";
  /** NUMERIC → string from pg */
  earned_points: string;
  /** NUMERIC → string from pg */
  entry_points: string;
  opponent_player_id: string;
  opponent_full_name: string;
  opponent_avatar: string | null;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/**
 * Return a paginated list of completed matches for the given user.
 *
 * Only matches with status = 'finished' are included.
 * Results are ordered by finished_at DESC (most recent first).
 *
 * The opponent's display info (player_id, full_name, avatar) is resolved
 * via a self-join on match_players + users.
 *
 * @param userId - The authenticated player's UUID.
 * @param limit  - Maximum rows to return (1–100).
 * @param offset - Rows to skip for pagination (≥ 0).
 */
export async function getMatchHistory(
  userId: string,
  limit: number,
  offset: number,
): Promise<{ rows: MatchHistoryRow[]; total: number }> {
  if (!pool) throw new Error("Database is not available.");

  // ── Total count (for pagination metadata) ─────────────────────────────────
  const countResult = await pool.query<{ total: string }>(
    `SELECT COUNT(*) AS total
     FROM matches m
     JOIN match_players mp ON mp.match_id = m.id
     WHERE mp.user_id = $1
       AND m.status   = 'finished'`,
    [userId],
  );
  const total = parseInt(countResult.rows[0]?.total ?? "0", 10);

  if (total === 0) {
    return { rows: [], total: 0 };
  }

  // ── Paginated match rows with opponent info ────────────────────────────────
  //
  // Self-join strategy:
  //   mp  = the requesting player's match_players row
  //   omp = the opponent's match_players row  (same match, different user)
  //   ou  = the opponent's users row
  //
  const { rows } = await pool.query<MatchHistoryRow>(
    `SELECT
       m.id            AS match_id,
       m.room_code,
       m.mode,
       m.started_at,
       m.finished_at,
       CASE WHEN m.winner_id = $1 THEN 'win' ELSE 'loss' END AS result,
       mp.earned_points,
       m.entry_points,
       ou.player_id    AS opponent_player_id,
       ou.full_name    AS opponent_full_name,
       ou.avatar       AS opponent_avatar
     FROM matches m
     JOIN match_players mp  ON mp.match_id = m.id  AND mp.user_id = $1
     JOIN match_players omp ON omp.match_id = m.id AND omp.user_id <> $1
     JOIN users ou           ON ou.id = omp.user_id
     WHERE m.status = 'finished'
     ORDER BY m.finished_at DESC
     LIMIT  $2
     OFFSET $3`,
    [userId, limit, offset],
  );

  return { rows, total };
}
