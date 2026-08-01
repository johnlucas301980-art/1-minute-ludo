/**
 * Game controller — Active Match Resume (Phase 6.5).
 *
 * GET /api/game/active-match
 * Returns whether the authenticated user has an active, resumable match.
 */

import type { Request, Response } from "express";
import { pool } from "../db/index.js";
import { getGameState } from "../socket/game_engine.js";
import { logger } from "../lib/logger.js";

/**
 * GET /api/game/active-match
 *
 * Checks the DB for a match with status = 'in_progress' where the
 * authenticated user is a participant, then cross-references the in-memory
 * game state to confirm the player is not eliminated and has lives remaining.
 *
 * Response 200 — active match found:
 *   { success: true, data: { hasActiveMatch: true, matchId, roomCode, playerColor, remainingLives } }
 *
 * Response 200 — no resumable match:
 *   { success: true, data: { hasActiveMatch: false } }
 */
export async function getActiveMatch(req: Request, res: Response): Promise<void> {
  const userId = req.user!.id;

  try {
    // Find an in-progress match this user is part of.
    const result = await pool!.query<{
      id: string;
      room_code: string;
      color: string;
    }>(
      `SELECT m.id, m.room_code, mp.color
         FROM matches m
         JOIN match_players mp ON mp.match_id = m.id
        WHERE m.status = 'in_progress'
          AND mp.user_id = $1
        LIMIT 1`,
      [userId],
    );

    if (result.rowCount === 0) {
      res.status(200).json({ success: true, data: { hasActiveMatch: false } });
      return;
    }

    const row = result.rows[0]!;
    const matchId = row.id;

    // Cross-reference with in-memory state to check lives and elimination.
    const state = getGameState(matchId);
    if (!state) {
      // DB says in_progress but no live engine state — treat as not resumable.
      res.status(200).json({ success: true, data: { hasActiveMatch: false } });
      return;
    }

    const player = state.players.find((p) => p.userId === userId);
    if (!player || player.eliminated || player.lives <= 0) {
      res.status(200).json({ success: true, data: { hasActiveMatch: false } });
      return;
    }

    res.status(200).json({
      success: true,
      data: {
        hasActiveMatch: true,
        matchId,
        roomCode: row.room_code,
        playerColor: player.color,
        remainingLives: player.lives,
      },
    });
  } catch (err) {
    logger.error({ err, userId }, "game.controller: failed to check active match.");
    res.status(500).json({ success: false, message: "Internal server error." });
  }
}
