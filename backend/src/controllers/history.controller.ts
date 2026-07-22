/**
 * History controller — Phase 8.1 (Match History Backend).
 *
 * GET /api/match/history — return a paginated list of the authenticated
 *                          player's completed matches, ordered newest first.
 */

import type { Request, Response } from "express";
import { getMatchHistory } from "../services/history.service.js";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const HISTORY_DEFAULT_LIMIT  = 20;
const HISTORY_MAX_LIMIT      = 100;
const HISTORY_MIN_LIMIT      = 1;
const HISTORY_DEFAULT_OFFSET = 0;

// ---------------------------------------------------------------------------
// GET /api/match/history
// ---------------------------------------------------------------------------

/**
 * Returns the authenticated player's completed match history.
 *
 * Query parameters:
 *   limit  — records to return (1–100, default 20).  Values < 1 → 400.
 *             Values > 100 → 400.  Non-numeric → default 20.
 *   offset — records to skip (≥ 0, default 0).  Negative values → default 0.
 */
export async function getHistory(req: Request, res: Response): Promise<void> {
  const log    = req.log;
  const userId = req.user!.id;

  // ── Parse and validate pagination params ─────────────────────────────────

  const rawLimit  = req.query["limit"];
  const rawOffset = req.query["offset"];

  // limit: explicit number required; non-numeric → use default
  let limit: number;
  if (rawLimit === undefined || rawLimit === "") {
    limit = HISTORY_DEFAULT_LIMIT;
  } else {
    const parsed = parseInt(String(rawLimit), 10);
    if (!Number.isFinite(parsed)) {
      limit = HISTORY_DEFAULT_LIMIT;
    } else if (parsed < HISTORY_MIN_LIMIT) {
      res.status(400).json({
        success: false,
        message: `limit must be at least ${HISTORY_MIN_LIMIT}.`,
      });
      return;
    } else if (parsed > HISTORY_MAX_LIMIT) {
      res.status(400).json({
        success: false,
        message: `limit must not exceed ${HISTORY_MAX_LIMIT}.`,
      });
      return;
    } else {
      limit = parsed;
    }
  }

  // offset: negative → clamp to 0 (silent, matches wallet/history behaviour)
  let offset: number;
  if (rawOffset === undefined || rawOffset === "") {
    offset = HISTORY_DEFAULT_OFFSET;
  } else {
    const parsed = parseInt(String(rawOffset), 10);
    offset = Number.isFinite(parsed) && parsed >= 0 ? parsed : HISTORY_DEFAULT_OFFSET;
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  try {
    const { rows, total } = await getMatchHistory(userId, limit, offset);

    res.status(200).json({
      success: true,
      data: {
        matches: rows.map((row) => ({
          match_id:      row.match_id,
          room_code:     row.room_code,
          mode:          row.mode,
          started_at:    row.started_at,
          finished_at:   row.finished_at,
          result:        row.result,
          earned_points: parseFloat(row.earned_points),
          entry_points:  parseFloat(row.entry_points),
          opponent: {
            player_id: row.opponent_player_id,
            full_name: row.opponent_full_name,
            avatar:    row.opponent_avatar,
          },
        })),
        pagination: {
          total,
          limit,
          offset,
        },
      },
    });
  } catch (err) {
    log.error({ err }, "GetHistory: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
