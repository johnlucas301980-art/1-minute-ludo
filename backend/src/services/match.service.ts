/**
 * Match service — database operations for matches and match_players.
 * Phase 5.1 — Matchmaking Backend Foundation.
 *
 * Controllers and socket handlers must never query the database directly;
 * they call the exported functions below.
 */

import { pool } from "../db/index";
import type { QueueEntry } from "./matchmaking.queue";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface MatchRow {
  id: string;
  room_code: string;
  mode: string;
  status: string;
  entry_points: string; // NUMERIC → string from pg
  player_count: number;
  winner_id: string | null;
  started_at: Date | null;
  finished_at: Date | null;
  created_at: Date;
}

export interface MatchPlayerRow {
  id: string;
  match_id: string;
  user_id: string;
  color: string;
  final_rank: number | null;
  earned_points: string; // NUMERIC → string from pg
  joined_at: Date;
}

export interface CreatedMatch {
  match: MatchRow;
  /** Two-element array; index 0 = player1, index 1 = player2. */
  players: [MatchPlayerRow, MatchPlayerRow];
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Colour pool for a 2-player match. */
const COLORS: readonly string[] = ["red", "blue"];

/** Characters used to build a room code (no visually confusable chars). */
const ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/** Length of generated room codes. */
const ROOM_CODE_LENGTH = 6;

/** Maximum attempts to generate a collision-free room code. */
const MAX_ROOM_CODE_ATTEMPTS = 10;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Generate a random alphanumeric room code of fixed length.
 * Uses a character set that excludes visually confusable characters
 * (I, O, 0, 1) so codes are easy to read aloud.
 */
function generateRoomCode(): string {
  let code = "";
  for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
    code += ROOM_CODE_CHARS[Math.floor(Math.random() * ROOM_CODE_CHARS.length)];
  }
  return code;
}

/**
 * Shuffle two colors and return them so color assignment is random.
 * Returns [colorForPlayer1, colorForPlayer2].
 */
function assignColors(): [string, string] {
  const colors = [...COLORS] as [string, string];
  if (Math.random() < 0.5) colors.reverse();
  return colors;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/**
 * Create a new match between two players inside a single PostgreSQL
 * transaction.
 *
 * Steps:
 *   1. Generate a collision-free 6-character room code.
 *   2. INSERT the match row.
 *   3. INSERT two match_players rows (one per player, with random color assignment).
 *   4. COMMIT.
 *
 * Both players' QueueEntry data are used directly — no additional DB round-
 * trips are required to look up display information for the match_found event.
 *
 * @param player1 - First queue entry (added to queue first, typically).
 * @param player2 - Second queue entry (triggered pairing).
 * @returns The created match and both player rows.
 * @throws Error when the database is unavailable or the transaction fails.
 */
export async function createMatch(
  player1: QueueEntry,
  player2: QueueEntry,
): Promise<CreatedMatch> {
  if (!pool) throw new Error("Database is not available.");

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // ── Generate a unique room code ──────────────────────────────────────────
    let roomCode = "";
    for (let attempt = 0; attempt < MAX_ROOM_CODE_ATTEMPTS; attempt++) {
      const candidate = generateRoomCode();
      const { rows } = await client.query<{ id: string }>(
        "SELECT id FROM matches WHERE room_code = $1 LIMIT 1",
        [candidate],
      );
      if (rows.length === 0) {
        roomCode = candidate;
        break;
      }
    }
    if (!roomCode) {
      throw new Error("Failed to generate a unique room code after maximum attempts.");
    }

    // ── Insert match row ─────────────────────────────────────────────────────
    const { rows: matchRows } = await client.query<MatchRow>(
      `INSERT INTO matches (room_code, mode, status, player_count)
       VALUES ($1, 'random', 'waiting', 2)
       RETURNING id, room_code, mode, status, entry_points, player_count,
                 winner_id, started_at, finished_at, created_at`,
      [roomCode],
    );
    const match = matchRows[0]!;

    // ── Assign colors randomly ───────────────────────────────────────────────
    const [color1, color2] = assignColors();

    // ── Insert player rows ───────────────────────────────────────────────────
    const { rows: mp1Rows } = await client.query<MatchPlayerRow>(
      `INSERT INTO match_players (match_id, user_id, color)
       VALUES ($1, $2, $3)
       RETURNING id, match_id, user_id, color, final_rank, earned_points, joined_at`,
      [match.id, player1.userId, color1],
    );

    const { rows: mp2Rows } = await client.query<MatchPlayerRow>(
      `INSERT INTO match_players (match_id, user_id, color)
       VALUES ($1, $2, $3)
       RETURNING id, match_id, user_id, color, final_rank, earned_points, joined_at`,
      [match.id, player2.userId, color2],
    );

    await client.query("COMMIT");

    return {
      match,
      players: [mp1Rows[0]!, mp2Rows[0]!],
    };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Fetch a single match row by its UUID.
 * Returns null when not found or the database is unavailable.
 */
export async function findMatchById(matchId: string): Promise<MatchRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<MatchRow>(
    `SELECT id, room_code, mode, status, entry_points, player_count,
            winner_id, started_at, finished_at, created_at
     FROM matches
     WHERE id = $1
     LIMIT 1`,
    [matchId],
  );
  return rows[0] ?? null;
}
