/**
 * Phase 9.2 — realtime delivery for persisted in-app notifications.
 *
 * PostgreSQL remains the source of truth. A dedicated LISTEN connection
 * receives committed notification changes, reads the row through the normal
 * pool, and emits only to the authenticated user's Socket.IO room.
 */

import pg from "pg";
import type { Server as SocketIOServer } from "socket.io";
import { pool } from "../db/index.js";
import { logger } from "../lib/logger.js";

const { Client } = pg;
const NOTIFICATION_CHANNEL = "notification_changes";
const USER_ROOM_PREFIX = "notifications:user:";

interface NotificationChange {
  action: "created" | "read_state_changed";
  notification_id: string;
  user_id: string;
}

interface NotificationRow {
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

export function notificationUserRoom(userId: string): string {
  return `${USER_ROOM_PREFIX}${userId}`;
}

function serializeNotification(row: NotificationRow) {
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    message: row.message,
    related_type: row.related_type,
    related_id: row.related_id,
    is_read: row.is_read,
    created_at: row.created_at.toISOString(),
    read_at: row.read_at?.toISOString() ?? null,
  };
}

async function readNotification(
  notificationId: string,
  userId: string,
): Promise<NotificationRow | null> {
  if (!pool) return null;

  const result = await pool.query<NotificationRow>(
    `SELECT
       id, user_id, type, title, message, related_type, related_id,
       event_key, is_read, created_at, read_at
     FROM notifications
     WHERE id = $1 AND user_id = $2`,
    [notificationId, userId],
  );

  return result.rows[0] ?? null;
}

async function readUnreadCount(userId: string): Promise<number> {
  if (!pool) return 0;

  const result = await pool.query<{ unread_count: string }>(
    `SELECT COUNT(*) AS unread_count
       FROM notifications
      WHERE user_id = $1
        AND is_read = FALSE`,
    [userId],
  );

  return Number.parseInt(result.rows[0]?.unread_count ?? "0", 10);
}

function parseChange(payload: string | undefined): NotificationChange | null {
  if (!payload) return null;

  try {
    const value = JSON.parse(payload) as Partial<NotificationChange>;
    if (
      (value.action !== "created" && value.action !== "read_state_changed") ||
      typeof value.notification_id !== "string" ||
      typeof value.user_id !== "string"
    ) {
      return null;
    }
    return value as NotificationChange;
  } catch {
    return null;
  }
}

async function publishChange(
  io: SocketIOServer,
  change: NotificationChange,
): Promise<void> {
  const unreadCount = await readUnreadCount(change.user_id);
  const room = notificationUserRoom(change.user_id);

  if (change.action === "created") {
    const notification = await readNotification(
      change.notification_id,
      change.user_id,
    );
    if (!notification) return;

    io.to(room).emit("notification_new", {
      notification: serializeNotification(notification),
      unread_count: unreadCount,
    });
    return;
  }

  io.to(room).emit("notifications_unread_count", {
    unread_count: unreadCount,
  });
}

/**
 * Attach the authenticated user's private notification room.
 *
 * The user ID is always taken from the server-authenticated socket data; no
 * client-supplied room name or user ID is accepted.
 */
export function setupNotificationRooms(io: SocketIOServer): void {
  io.on("connection", (socket) => {
    const user = socket.data.user as { id?: string } | undefined;
    if (!user?.id) return;
    const userId = user.id;

    void (async () => {
      try {
        await socket.join(notificationUserRoom(userId));
        const unreadCount = await readUnreadCount(userId);
        socket.emit("notifications_unread_count", { unread_count: unreadCount });
      } catch (err) {
        logger.error(
          { err, socketId: socket.id, userId },
          "Notification room join failed.",
        );
      }
    })();
  });
}

/**
 * Start the PostgreSQL LISTEN bridge. It is intentionally best-effort: a
 * delivery outage must never affect persisted notifications or gameplay.
 */
export async function startNotificationDelivery(
  io: SocketIOServer,
): Promise<void> {
  const databaseUrl = process.env["DATABASE_URL"];
  if (!databaseUrl) {
    logger.warn("Notification realtime delivery disabled: DATABASE_URL is not set.");
    return;
  }

  const client = new Client({ connectionString: databaseUrl });

  client.on("error", (err) => {
    logger.error({ err }, "Notification realtime LISTEN connection error.");
  });

  client.on("notification", (message) => {
    const change = parseChange(message.payload);
    if (!change) {
      logger.warn("Notification realtime received an invalid database event.");
      return;
    }

    publishChange(io, change).catch((err) => {
      logger.error({ err, notificationId: change.notification_id }, "Notification realtime publish failed.");
    });
  });

  try {
    await client.connect();
    await client.query(`LISTEN ${NOTIFICATION_CHANNEL}`);
    logger.info("Notification realtime delivery listener started.");
  } catch (err) {
    logger.error({ err }, "Notification realtime listener could not start.");
    await client.end().catch(() => undefined);
  }
}