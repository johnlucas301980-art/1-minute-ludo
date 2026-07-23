/**
 * In-app notification service — Phase 9.1.
 *
 * All direct database access for persisted notifications lives here.
 * Controllers and gameplay integration points must use this module.
 */

import { pool } from "../db/index.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface NotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  message: string;
  related_type: string | null;
  related_id: string | null;
  event_key: string | null;
  is_read: boolean;
  created_at: Date;
  read_at: Date | null;
}

export interface CreateNotificationInput {
  userId: string;
  type: string;
  title: string;
  message: string;
  relatedType?: string | null;
  relatedId?: string | null;
  eventKey?: string | null;
}

export interface NotificationPage {
  rows: NotificationRow[];
  total: number;
  unreadCount: number;
}

// ---------------------------------------------------------------------------
// Creation
// ---------------------------------------------------------------------------

/**
 * Create one notification.
 *
 * A non-null event key makes creation idempotent for a user. This is required
 * because match completion handlers may be retried after the source match has
 * already been finalized.
 */
export async function createNotification(
  input: CreateNotificationInput,
): Promise<NotificationRow> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<NotificationRow>(
    `INSERT INTO notifications
       (user_id, type, title, message, related_type, related_id, event_key)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (user_id, event_key)
       WHERE event_key IS NOT NULL
     DO UPDATE SET id = notifications.id
     RETURNING
       id, user_id, type, title, message, related_type, related_id,
       event_key, is_read, created_at, read_at`,
    [
      input.userId,
      input.type,
      input.title,
      input.message,
      input.relatedType ?? null,
      input.relatedId ?? null,
      input.eventKey ?? null,
    ],
  );

  return rows[0]!;
}

/**
 * Create the two user-owned notifications for a normally completed match.
 *
 * This is intentionally limited to the normal completed-win path. Forfeit,
 * disconnect, and pending-match cancellation notifications are separate scope.
 */
export async function createMatchCompletionNotifications(
  matchId: string,
  winnerId: string,
): Promise<void> {
  if (!pool) throw new Error("Database is not available.");

  const { rows: players } = await pool.query<{ user_id: string }>(
    `SELECT user_id
       FROM match_players
      WHERE match_id = $1
      ORDER BY joined_at ASC`,
    [matchId],
  );

  const loser = players.find((player) => player.user_id !== winnerId);
  if (!players.some((player) => player.user_id === winnerId) || !loser) {
    throw new Error("Completed match must have exactly one winner and one opponent.");
  }

  await Promise.all([
    createNotification({
      userId: winnerId,
      type: "match_completed",
      title: "Match completed",
      message: "You won your match.",
      relatedType: "match",
      relatedId: matchId,
      eventKey: `match:${matchId}:completed:${winnerId}`,
    }),
    createNotification({
      userId: loser.user_id,
      type: "match_completed",
      title: "Match completed",
      message: "You lost your match.",
      relatedType: "match",
      relatedId: matchId,
      eventKey: `match:${matchId}:completed:${loser.user_id}`,
    }),
  ]);
}

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------

export async function getNotifications(
  userId: string,
  limit: number,
  offset: number,
): Promise<NotificationPage> {
  if (!pool) throw new Error("Database is not available.");

  const [countResult, unreadResult, notificationResult] = await Promise.all([
    pool.query<{ total: string }>(
      "SELECT COUNT(*) AS total FROM notifications WHERE user_id = $1",
      [userId],
    ),
    pool.query<{ unread_count: string }>(
      `SELECT COUNT(*) AS unread_count
         FROM notifications
        WHERE user_id = $1
          AND is_read = FALSE`,
      [userId],
    ),
    pool.query<NotificationRow>(
      `SELECT
         id, user_id, type, title, message, related_type, related_id,
         event_key, is_read, created_at, read_at
       FROM notifications
       WHERE user_id = $1
       ORDER BY created_at DESC, id DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    ),
  ]);

  return {
    rows: notificationResult.rows,
    total: parseInt(countResult.rows[0]?.total ?? "0", 10),
    unreadCount: parseInt(unreadResult.rows[0]?.unread_count ?? "0", 10),
  };
}

// ---------------------------------------------------------------------------
// Read state
// ---------------------------------------------------------------------------

export async function markNotificationRead(
  userId: string,
  notificationId: string,
): Promise<NotificationRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<NotificationRow>(
    `UPDATE notifications
        SET is_read = TRUE,
            read_at = COALESCE(read_at, NOW())
      WHERE id = $1
        AND user_id = $2
      RETURNING
        id, user_id, type, title, message, related_type, related_id,
        event_key, is_read, created_at, read_at`,
    [notificationId, userId],
  );

  return rows[0] ?? null;
}

export async function markAllNotificationsRead(
  userId: string,
): Promise<number> {
  if (!pool) throw new Error("Database is not available.");

  const result = await pool.query(
    `UPDATE notifications
        SET is_read = TRUE,
            read_at = COALESCE(read_at, NOW())
      WHERE user_id = $1
        AND is_read = FALSE`,
    [userId],
  );

  return result.rowCount ?? 0;
}