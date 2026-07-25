import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import {
  createMatchCompletionNotifications,
  createNotification,
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  type NotificationRow,
} from "./notification.service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeRow(overrides: Partial<NotificationRow> = {}): NotificationRow {
  return {
    id: "notif-1",
    user_id: "user-1",
    type: "match_completed",
    title: "Match completed",
    message: "You won your match.",
    related_type: "match",
    related_id: "match-1",
    event_key: "match:match-1:completed:user-1",
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
// createNotification
// ---------------------------------------------------------------------------

describe("createNotification", () => {
  it("inserts a notification and returns the created row", async () => {
    const row = makeRow();
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await createNotification({
      userId: "user-1",
      type: "match_completed",
      title: "Match completed",
      message: "You won your match.",
      relatedType: "match",
      relatedId: "match-1",
      eventKey: "match:match-1:completed:user-1",
    });

    expect(result).toEqual(row);
    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO notifications/i);
    expect(params).toEqual([
      "user-1",
      "match_completed",
      "Match completed",
      "You won your match.",
      "match",
      "match-1",
      "match:match-1:completed:user-1",
    ]);
  });

  it("includes the ON CONFLICT idempotency clause in the SQL", async () => {
    pool.query.mockResolvedValue({ rows: [makeRow()] });

    await createNotification({
      userId: "user-1",
      type: "match_completed",
      title: "Match completed",
      message: "You won your match.",
      eventKey: "match:match-1:completed:user-1",
    });

    const [sql] = pool.query.mock.calls[0];
    expect(sql).toMatch(/ON CONFLICT/i);
    expect(sql).toMatch(/DO UPDATE/i);
  });

  it("coerces absent optional fields to null", async () => {
    pool.query.mockResolvedValue({ rows: [makeRow({ related_type: null, related_id: null, event_key: null })] });

    await createNotification({
      userId: "user-1",
      type: "info",
      title: "Hello",
      message: "World",
      // relatedType, relatedId, eventKey intentionally omitted
    });

    const [, params] = pool.query.mock.calls[0];
    expect(params[4]).toBeNull(); // relatedType
    expect(params[5]).toBeNull(); // relatedId
    expect(params[6]).toBeNull(); // eventKey
  });

  it("propagates database errors to the caller", async () => {
    pool.query.mockRejectedValue(new Error("insert failed"));

    await expect(
      createNotification({ userId: "user-1", type: "t", title: "T", message: "M" }),
    ).rejects.toThrow("insert failed");
  });
});

// ---------------------------------------------------------------------------
// createMatchCompletionNotifications
// ---------------------------------------------------------------------------

describe("createMatchCompletionNotifications", () => {
  it("sends a win notification to the winner and a loss notification to the loser", async () => {
    const winRow = makeRow({ user_id: "user-winner", message: "You won your match." });
    const lossRow = makeRow({ user_id: "user-loser", message: "You lost your match." });

    pool.query
      .mockResolvedValueOnce({ rows: [{ user_id: "user-winner" }, { user_id: "user-loser" }] })
      .mockResolvedValueOnce({ rows: [winRow] })  // winner notification
      .mockResolvedValueOnce({ rows: [lossRow] }); // loser notification

    await createMatchCompletionNotifications("match-1", "user-winner");

    // First call: match_players lookup
    const [playerSql, playerParams] = pool.query.mock.calls[0];
    expect(playerSql).toMatch(/match_players/i);
    expect(playerParams).toEqual(["match-1"]);

    // Remaining calls: two notification inserts (Promise.all order)
    const insertCalls = pool.query.mock.calls.slice(1);
    expect(insertCalls).toHaveLength(2);

    const messages = insertCalls.map((call: unknown[]) => (call[1] as unknown[])[3]);
    expect(messages).toContain("You won your match.");
    expect(messages).toContain("You lost your match.");
  });

  it("sets the correct event keys for winner and loser", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ user_id: "user-winner" }, { user_id: "user-loser" }] })
      .mockResolvedValue({ rows: [makeRow()] });

    await createMatchCompletionNotifications("match-42", "user-winner");

    const insertCalls = pool.query.mock.calls.slice(1);
    const eventKeys = insertCalls.map((call: unknown[]) => (call[1] as unknown[])[6]);
    expect(eventKeys).toContain("match:match-42:completed:user-winner");
    expect(eventKeys).toContain("match:match-42:completed:user-loser");
  });

  it("throws when the winner is not among the match players", async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ user_id: "user-a" }, { user_id: "user-b" }],
    });

    await expect(
      createMatchCompletionNotifications("match-1", "user-unknown"),
    ).rejects.toThrow("Completed match must have exactly one winner and one opponent.");
  });

  it("throws when there is no opponent for the winner", async () => {
    // Only one player row, and it is the winner — no loser can be found
    pool.query.mockResolvedValueOnce({ rows: [{ user_id: "user-winner" }] });

    await expect(
      createMatchCompletionNotifications("match-1", "user-winner"),
    ).rejects.toThrow("Completed match must have exactly one winner and one opponent.");
  });

  it("throws when match_players returns an empty result", async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    await expect(
      createMatchCompletionNotifications("match-1", "user-winner"),
    ).rejects.toThrow("Completed match must have exactly one winner and one opponent.");
  });
});

// ---------------------------------------------------------------------------
// getNotifications
// ---------------------------------------------------------------------------

describe("getNotifications", () => {
  it("returns rows, total, and unreadCount from three parallel queries", async () => {
    const rows = [makeRow(), makeRow({ id: "notif-2" })];

    // Promise.all fires queries in array order: count, unread, rows
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "5" }] })
      .mockResolvedValueOnce({ rows: [{ unread_count: "3" }] })
      .mockResolvedValueOnce({ rows });

    const result = await getNotifications("user-1", 20, 0);

    expect(result.total).toBe(5);
    expect(result.unreadCount).toBe(3);
    expect(result.rows).toEqual(rows);
    expect(pool.query).toHaveBeenCalledTimes(3);
  });

  it("passes limit and offset to the rows query", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "0" }] })
      .mockResolvedValueOnce({ rows: [{ unread_count: "0" }] })
      .mockResolvedValueOnce({ rows: [] });

    await getNotifications("user-1", 10, 30);

    const rowsQueryParams = pool.query.mock.calls[2][1] as unknown[];
    expect(rowsQueryParams).toContain(10);  // limit
    expect(rowsQueryParams).toContain(30);  // offset
  });

  it("returns zero totals and empty rows when the user has no notifications", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "0" }] })
      .mockResolvedValueOnce({ rows: [{ unread_count: "0" }] })
      .mockResolvedValueOnce({ rows: [] });

    const result = await getNotifications("user-1", 20, 0);

    expect(result.total).toBe(0);
    expect(result.unreadCount).toBe(0);
    expect(result.rows).toEqual([]);
  });

  it("defaults missing count strings to zero", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] })         // no total row
      .mockResolvedValueOnce({ rows: [] })         // no unread row
      .mockResolvedValueOnce({ rows: [] });

    const result = await getNotifications("user-1", 20, 0);

    expect(result.total).toBe(0);
    expect(result.unreadCount).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// markNotificationRead
// ---------------------------------------------------------------------------

describe("markNotificationRead", () => {
  it("returns the updated notification row", async () => {
    const row = makeRow({ is_read: true, read_at: new Date() });
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await markNotificationRead("user-1", "notif-1");

    expect(result).toEqual(row);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/is_read = TRUE/i);
    expect(params).toEqual(["notif-1", "user-1"]);
  });

  it("returns null when the notification does not exist or belongs to another user", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    const result = await markNotificationRead("user-1", "notif-missing");

    expect(result).toBeNull();
  });

  it("scopes the update to the requesting user_id", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await markNotificationRead("user-99", "notif-1");

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/user_id/i);
    expect(params).toContain("user-99");
  });
});

// ---------------------------------------------------------------------------
// markAllNotificationsRead
// ---------------------------------------------------------------------------

describe("markAllNotificationsRead", () => {
  it("returns the number of rows updated", async () => {
    pool.query.mockResolvedValue({ rowCount: 4 });

    const result = await markAllNotificationsRead("user-1");

    expect(result).toBe(4);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/is_read = TRUE/i);
    expect(sql).toMatch(/is_read = FALSE/i);
    expect(params).toEqual(["user-1"]);
  });

  it("returns 0 when all notifications were already read", async () => {
    pool.query.mockResolvedValue({ rowCount: 0 });

    const result = await markAllNotificationsRead("user-1");

    expect(result).toBe(0);
  });

  it("returns 0 when rowCount is null", async () => {
    pool.query.mockResolvedValue({ rowCount: null });

    const result = await markAllNotificationsRead("user-1");

    expect(result).toBe(0);
  });
});
