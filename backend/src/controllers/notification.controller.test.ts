import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const {
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} = vi.hoisted(() => ({
  getNotifications: vi.fn(),
  markAllNotificationsRead: vi.fn(),
  markNotificationRead: vi.fn(),
}));

vi.mock("../services/notification.service.js", () => ({
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
}));
vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import {
  getNotificationsHandler,
  markAllNotificationsReadHandler,
  markNotificationReadHandler,
} from "./notification.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq({
  userId = "user-1",
  query = {} as Record<string, string>,
  params = {} as Record<string, string>,
} = {}): Request {
  return {
    log: { error: vi.fn() },
    user: { id: userId },
    query,
    params,
  } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

function makeNotificationRow(overrides = {}) {
  return {
    id: "notif-1",
    type: "match_result",
    title: "Match Over",
    message: "You won!",
    related_type: null,
    related_id: null,
    is_read: false,
    created_at: new Date("2026-01-01T00:00:00Z"),
    read_at: null,
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// getNotificationsHandler
// ---------------------------------------------------------------------------

describe("getNotificationsHandler", () => {
  it("returns 200 with paginated notifications using default params", async () => {
    const row = makeNotificationRow();
    getNotifications.mockResolvedValue({ rows: [row], total: 1, unreadCount: 1 });

    const res = makeRes();
    await getNotificationsHandler(makeReq(), res);

    expect(getNotifications).toHaveBeenCalledWith("user-1", 20, 0);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        notifications: [
          {
            id: row.id,
            type: row.type,
            title: row.title,
            message: row.message,
            related_type: row.related_type,
            related_id: row.related_id,
            is_read: row.is_read,
            created_at: row.created_at,
            read_at: row.read_at,
          },
        ],
        pagination: { total: 1, limit: 20, offset: 0 },
        unread_count: 1,
      },
    });
  });

  it("forwards valid limit and offset to the service", async () => {
    getNotifications.mockResolvedValue({ rows: [], total: 0, unreadCount: 0 });

    await getNotificationsHandler(makeReq({ query: { limit: "5", offset: "10" } }), makeRes());

    expect(getNotifications).toHaveBeenCalledWith("user-1", 5, 10);
  });

  it("returns 400 when limit is below minimum", async () => {
    const res = makeRes();
    await getNotificationsHandler(makeReq({ query: { limit: "0" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getNotifications).not.toHaveBeenCalled();
  });

  it("returns 400 when limit exceeds maximum", async () => {
    const res = makeRes();
    await getNotificationsHandler(makeReq({ query: { limit: "101" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getNotifications).not.toHaveBeenCalled();
  });

  it("returns 500 when getNotifications throws", async () => {
    getNotifications.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getNotificationsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// markAllNotificationsReadHandler
// ---------------------------------------------------------------------------

describe("markAllNotificationsReadHandler", () => {
  it("returns 200 with marked_count and current unread_count", async () => {
    markAllNotificationsRead.mockResolvedValue(5);
    getNotifications.mockResolvedValue({ rows: [], total: 0, unreadCount: 0 });

    const res = makeRes();
    await markAllNotificationsReadHandler(makeReq(), res);

    expect(markAllNotificationsRead).toHaveBeenCalledWith("user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { marked_count: 5, unread_count: 0 },
    });
  });

  it("returns 500 when markAllNotificationsRead throws", async () => {
    markAllNotificationsRead.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await markAllNotificationsReadHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// markNotificationReadHandler
// ---------------------------------------------------------------------------

describe("markNotificationReadHandler", () => {
  const VALID_UUID = "550e8400-e29b-41d4-a716-446655440000";

  it("returns 400 when the notification id is not a valid UUID", async () => {
    const res = makeRes();
    await markNotificationReadHandler(
      makeReq({ params: { id: "not-a-uuid" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "A valid notification id is required.",
    });
    expect(markNotificationRead).not.toHaveBeenCalled();
  });

  it("returns 200 with serialized notification when found and marked", async () => {
    const row = makeNotificationRow({ id: VALID_UUID, is_read: true, read_at: new Date() });
    markNotificationRead.mockResolvedValue(row);

    const res = makeRes();
    await markNotificationReadHandler(
      makeReq({ params: { id: VALID_UUID } }),
      res,
    );

    expect(markNotificationRead).toHaveBeenCalledWith("user-1", VALID_UUID);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        notification: expect.objectContaining({ id: VALID_UUID, is_read: true }),
      },
    });
  });

  it("returns 404 when markNotificationRead returns null (not found)", async () => {
    markNotificationRead.mockResolvedValue(null);

    const res = makeRes();
    await markNotificationReadHandler(
      makeReq({ params: { id: VALID_UUID } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Notification not found.",
    });
  });

  it("returns 500 when markNotificationRead throws", async () => {
    markNotificationRead.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await markNotificationReadHandler(
      makeReq({ params: { id: VALID_UUID } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
