/**
 * In-app notification controllers — Phase 9.1.
 */

import type { Request, Response } from "express";
import {
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "../services/notification.service.js";

const DEFAULT_LIMIT = 20;
const MIN_LIMIT = 1;
const MAX_LIMIT = 100;

function parsePagination(req: Request): { limit: number; offset: number } | {
  error: string;
} {
  const rawLimit = req.query["limit"];
  const rawOffset = req.query["offset"];

  let limit = DEFAULT_LIMIT;
  if (rawLimit !== undefined && rawLimit !== "") {
    const parsed = Number.parseInt(String(rawLimit), 10);
    if (!Number.isFinite(parsed)) {
      limit = DEFAULT_LIMIT;
    } else if (parsed < MIN_LIMIT) {
      return { error: `limit must be at least ${MIN_LIMIT}.` };
    } else if (parsed > MAX_LIMIT) {
      return { error: `limit must not exceed ${MAX_LIMIT}.` };
    } else {
      limit = parsed;
    }
  }

  let offset = 0;
  if (rawOffset !== undefined && rawOffset !== "") {
    const parsed = Number.parseInt(String(rawOffset), 10);
    offset = Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
  }

  return { limit, offset };
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function serializeNotification(row: {
  id: string;
  type: string;
  title: string;
  message: string;
  related_type: string | null;
  related_id: string | null;
  is_read: boolean;
  created_at: Date;
  read_at: Date | null;
}) {
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    message: row.message,
    related_type: row.related_type,
    related_id: row.related_id,
    is_read: row.is_read,
    created_at: row.created_at,
    read_at: row.read_at,
  };
}

export async function getNotificationsHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  try {
    const page = await getNotifications(req.user!.id, parsed.limit, parsed.offset);
    res.status(200).json({
      success: true,
      data: {
        notifications: page.rows.map(serializeNotification),
        pagination: {
          total: page.total,
          limit: parsed.limit,
          offset: parsed.offset,
        },
        unread_count: page.unreadCount,
      },
    });
  } catch (err) {
    req.log.error({ err }, "GetNotifications: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

export async function markNotificationReadHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const rawNotificationId = req.params["id"];
  const notificationId =
    typeof rawNotificationId === "string" ? rawNotificationId : undefined;
  if (!notificationId || !isUuid(notificationId)) {
    res.status(400).json({
      success: false,
      message: "A valid notification id is required.",
    });
    return;
  }

  try {
    const notification = await markNotificationRead(req.user!.id, notificationId);
    if (!notification) {
      res.status(404).json({
        success: false,
        message: "Notification not found.",
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: {
        notification: serializeNotification(notification),
      },
    });
  } catch (err) {
    req.log.error({ err, notificationId }, "MarkNotificationRead: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

export async function markAllNotificationsReadHandler(
  req: Request,
  res: Response,
): Promise<void> {
  try {
    const markedCount = await markAllNotificationsRead(req.user!.id);
    const page = await getNotifications(req.user!.id, 1, 0);
    res.status(200).json({
      success: true,
      data: {
        marked_count: markedCount,
        unread_count: page.unreadCount,
      },
    });
  } catch (err) {
    req.log.error({ err }, "MarkAllNotificationsRead: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}