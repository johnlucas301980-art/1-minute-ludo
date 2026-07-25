import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const { mockPool, mockClient, MockClient, mockLogger } = vi.hoisted(() => {
  const mockPool = { query: vi.fn() };

  const mockClient = {
    on: vi.fn(),
    connect: vi.fn(),
    query: vi.fn(),
    end: vi.fn(),
  };

  const MockClient = vi.fn(() => mockClient);

  const mockLogger = {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  };

  return { mockPool, mockClient, MockClient, mockLogger };
});

vi.mock("pg", () => ({ default: { Client: MockClient } }));
vi.mock("../db/index.js", () => ({ pool: mockPool }));
vi.mock("../lib/logger.js", () => ({ logger: mockLogger }));

import {
  notificationUserRoom,
  setupNotificationRooms,
  startNotificationDelivery,
} from "./notification_delivery.js";

// ---------------------------------------------------------------------------
// Type helpers
// ---------------------------------------------------------------------------

interface FakeNotificationRow {
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

type EventFn = (...args: unknown[]) => unknown;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeRow(overrides: Partial<FakeNotificationRow> = {}): FakeNotificationRow {
  return {
    id: "notif-1",
    user_id: "user-1",
    type: "match_completed",
    title: "Match completed",
    message: "You won!",
    related_type: "match",
    related_id: "match-1",
    event_key: "key-1",
    is_read: false,
    created_at: new Date("2026-01-01T00:00:00.000Z"),
    read_at: null,
    ...overrides,
  };
}

/** Build a fake Socket.IO server that captures handlers. */
function makeIo() {
  const ioHandlers: Record<string, EventFn> = {};
  const emitFn = vi.fn();
  const toFn = vi.fn().mockReturnValue({ emit: emitFn });
  return {
    on: vi.fn((event: string, handler: EventFn) => {
      ioHandlers[event] = handler;
    }),
    to: toFn,
    _emit: emitFn,
    _trigger: (event: string, ...args: unknown[]) => ioHandlers[event]?.(...args),
  };
}

/** Set up mockClient.on to capture event handlers and return the map. */
function captureClientHandlers(): Record<string, EventFn> {
  const handlers: Record<string, EventFn> = {};
  mockClient.on.mockImplementation((event: string, handler: EventFn) => {
    handlers[event] = handler;
  });
  return handlers;
}

/** Flush all queued microtasks and one macrotask tick. */
const flush = () => new Promise<void>((resolve) => setTimeout(resolve, 0));

beforeEach(() => {
  vi.resetAllMocks();
  // client.end() is awaited with .catch() in the error path; it must return a
  // Promise by default so that the chained .catch() call doesn't throw.
  mockClient.end.mockResolvedValue(undefined);
  delete process.env["DATABASE_URL"];
});

// ---------------------------------------------------------------------------
// notificationUserRoom
// ---------------------------------------------------------------------------

describe("notificationUserRoom", () => {
  it("returns the expected room string for a given user ID", () => {
    expect(notificationUserRoom("user-abc")).toBe("notifications:user:user-abc");
  });

  it("embeds the user ID verbatim in the room name", () => {
    const id = "550e8400-e29b-41d4-a716-446655440000";
    expect(notificationUserRoom(id)).toContain(id);
  });

  it("produces different room names for different user IDs", () => {
    expect(notificationUserRoom("user-1")).not.toBe(notificationUserRoom("user-2"));
  });
});

// ---------------------------------------------------------------------------
// setupNotificationRooms
// ---------------------------------------------------------------------------

describe("setupNotificationRooms", () => {
  it("registers a 'connection' handler on the io server", () => {
    const io = makeIo();
    setupNotificationRooms(io as never);
    expect(io.on).toHaveBeenCalledWith("connection", expect.any(Function));
  });

  it("does not join a room when socket has no user data at all", async () => {
    const io = makeIo();
    setupNotificationRooms(io as never);
    const socket = { id: "s-1", data: {}, join: vi.fn(), emit: vi.fn() };
    io._trigger("connection", socket);
    await flush();
    expect(socket.join).not.toHaveBeenCalled();
    expect(socket.emit).not.toHaveBeenCalled();
  });

  it("does not join a room when socket.data.user has no id", async () => {
    const io = makeIo();
    setupNotificationRooms(io as never);
    const socket = { id: "s-1", data: { user: {} }, join: vi.fn(), emit: vi.fn() };
    io._trigger("connection", socket);
    await flush();
    expect(socket.join).not.toHaveBeenCalled();
  });

  it("joins the user notification room on connection with a valid user ID", async () => {
    const io = makeIo();
    mockPool.query.mockResolvedValue({ rows: [{ unread_count: "0" }] });
    setupNotificationRooms(io as never);
    const socket = {
      id: "s-1",
      data: { user: { id: "user-1" } },
      join: vi.fn().mockResolvedValue(undefined),
      emit: vi.fn(),
    };
    io._trigger("connection", socket);
    await flush();
    expect(socket.join).toHaveBeenCalledWith("notifications:user:user-1");
  });

  it("emits the current unread count to the socket after joining", async () => {
    const io = makeIo();
    mockPool.query.mockResolvedValue({ rows: [{ unread_count: "7" }] });
    setupNotificationRooms(io as never);
    const socket = {
      id: "s-1",
      data: { user: { id: "user-1" } },
      join: vi.fn().mockResolvedValue(undefined),
      emit: vi.fn(),
    };
    io._trigger("connection", socket);
    await flush();
    expect(socket.emit).toHaveBeenCalledWith("notifications_unread_count", { unread_count: 7 });
  });

  it("emits zero as unread count when the pool returns no row", async () => {
    const io = makeIo();
    mockPool.query.mockResolvedValue({ rows: [] });
    setupNotificationRooms(io as never);
    const socket = {
      id: "s-1",
      data: { user: { id: "user-1" } },
      join: vi.fn().mockResolvedValue(undefined),
      emit: vi.fn(),
    };
    io._trigger("connection", socket);
    await flush();
    expect(socket.emit).toHaveBeenCalledWith("notifications_unread_count", { unread_count: 0 });
  });

  it("logs an error and does not emit when socket.join rejects", async () => {
    const io = makeIo();
    setupNotificationRooms(io as never);
    const socket = {
      id: "s-1",
      data: { user: { id: "user-1" } },
      join: vi.fn().mockRejectedValue(new Error("join failed")),
      emit: vi.fn(),
    };
    io._trigger("connection", socket);
    await flush();
    expect(mockLogger.error).toHaveBeenCalledWith(
      expect.objectContaining({ socketId: "s-1", userId: "user-1" }),
      "Notification room join failed.",
    );
    expect(socket.emit).not.toHaveBeenCalled();
  });

  it("handles multiple simultaneous connections independently", async () => {
    const io = makeIo();
    mockPool.query.mockResolvedValue({ rows: [{ unread_count: "1" }] });
    setupNotificationRooms(io as never);

    const socketA = {
      id: "s-a",
      data: { user: { id: "user-a" } },
      join: vi.fn().mockResolvedValue(undefined),
      emit: vi.fn(),
    };
    const socketB = {
      id: "s-b",
      data: { user: { id: "user-b" } },
      join: vi.fn().mockResolvedValue(undefined),
      emit: vi.fn(),
    };

    io._trigger("connection", socketA);
    io._trigger("connection", socketB);
    await flush();

    expect(socketA.join).toHaveBeenCalledWith("notifications:user:user-a");
    expect(socketB.join).toHaveBeenCalledWith("notifications:user:user-b");
  });
});

// ---------------------------------------------------------------------------
// startNotificationDelivery — startup behaviour
// ---------------------------------------------------------------------------

describe("startNotificationDelivery — startup", () => {
  it("logs a warning and returns without creating a Client when DATABASE_URL is missing", async () => {
    const io = makeIo();
    await startNotificationDelivery(io as never);
    expect(MockClient).not.toHaveBeenCalled();
    expect(mockLogger.warn).toHaveBeenCalledWith(
      expect.stringContaining("DATABASE_URL"),
    );
  });

  it("creates a pg Client with the DATABASE_URL connection string", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    expect(MockClient).toHaveBeenCalledWith({
      connectionString: "postgresql://localhost/test",
    });
  });

  it("calls client.connect()", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    expect(mockClient.connect).toHaveBeenCalledOnce();
  });

  it("issues a LISTEN command on the notification_changes channel", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    const [sql] = (mockClient.query.mock.calls[0] as [string]) ?? [];
    expect(sql).toMatch(/LISTEN\s+notification_changes/i);
  });

  it("logs info after a successful listener start", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    expect(mockLogger.info).toHaveBeenCalledWith(
      expect.stringContaining("Notification realtime delivery listener started"),
    );
  });

  it("logs an error and does not throw when client.connect() rejects", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    captureClientHandlers();
    mockClient.connect.mockRejectedValue(new Error("connection refused"));
    const io = makeIo();
    await expect(startNotificationDelivery(io as never)).resolves.not.toThrow();
    expect(mockLogger.error).toHaveBeenCalledWith(
      expect.objectContaining({ err: expect.any(Error) }),
      "Notification realtime listener could not start.",
    );
  });

  it("calls client.end() when client.connect() throws", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    captureClientHandlers();
    mockClient.connect.mockRejectedValue(new Error("connection refused"));
    const io = makeIo();
    await startNotificationDelivery(io as never);
    expect(mockClient.end).toHaveBeenCalledOnce();
  });
});

// ---------------------------------------------------------------------------
// startNotificationDelivery — client event handlers
// ---------------------------------------------------------------------------

describe("startNotificationDelivery — client event handlers", () => {
  it("registers an 'error' event handler on the client", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    const handlers = captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    expect(handlers["error"]).toBeTypeOf("function");
  });

  it("logs an error when the pg client emits an 'error' event", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    const handlers = captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    const err = new Error("pg connection lost");
    handlers["error"]!(err);
    expect(mockLogger.error).toHaveBeenCalledWith(
      expect.objectContaining({ err }),
      "Notification realtime LISTEN connection error.",
    );
  });

  it("registers a 'notification' event handler on the client", async () => {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    const handlers = captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    expect(handlers["notification"]).toBeTypeOf("function");
  });
});

// ---------------------------------------------------------------------------
// parseChange — tested indirectly via the 'notification' client event
// ---------------------------------------------------------------------------

describe("parseChange — invalid payloads", () => {
  async function getNotificationHandler(io: ReturnType<typeof makeIo>) {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    const handlers = captureClientHandlers();
    await startNotificationDelivery(io as never);
    return handlers["notification"]!;
  }

  it("logs a warning when payload is undefined", async () => {
    const io = makeIo();
    const handler = await getNotificationHandler(io);
    handler({ payload: undefined });
    await flush();
    expect(mockLogger.warn).toHaveBeenCalledWith(
      "Notification realtime received an invalid database event.",
    );
  });

  it("logs a warning when payload is not valid JSON", async () => {
    const io = makeIo();
    const handler = await getNotificationHandler(io);
    handler({ payload: "not-json{{{" });
    await flush();
    expect(mockLogger.warn).toHaveBeenCalledWith(
      "Notification realtime received an invalid database event.",
    );
  });

  it("logs a warning when action is an unrecognised value", async () => {
    const io = makeIo();
    const handler = await getNotificationHandler(io);
    handler({
      payload: JSON.stringify({
        action: "deleted",
        notification_id: "n-1",
        user_id: "u-1",
      }),
    });
    await flush();
    expect(mockLogger.warn).toHaveBeenCalledWith(
      "Notification realtime received an invalid database event.",
    );
  });

  it("logs a warning when notification_id is missing", async () => {
    const io = makeIo();
    const handler = await getNotificationHandler(io);
    handler({
      payload: JSON.stringify({ action: "created", user_id: "u-1" }),
    });
    await flush();
    expect(mockLogger.warn).toHaveBeenCalledWith(
      "Notification realtime received an invalid database event.",
    );
  });

  it("logs a warning when user_id is missing", async () => {
    const io = makeIo();
    const handler = await getNotificationHandler(io);
    handler({
      payload: JSON.stringify({ action: "created", notification_id: "n-1" }),
    });
    await flush();
    expect(mockLogger.warn).toHaveBeenCalledWith(
      "Notification realtime received an invalid database event.",
    );
  });

  it("logs a warning when notification_id is not a string", async () => {
    const io = makeIo();
    const handler = await getNotificationHandler(io);
    handler({
      payload: JSON.stringify({ action: "created", notification_id: 42, user_id: "u-1" }),
    });
    await flush();
    expect(mockLogger.warn).toHaveBeenCalledWith(
      "Notification realtime received an invalid database event.",
    );
  });
});

// ---------------------------------------------------------------------------
// publishChange — tested indirectly via the 'notification' client event
// ---------------------------------------------------------------------------

describe("publishChange — action: created", () => {
  async function setup() {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    const handlers = captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    const trigger = (payload: object) =>
      handlers["notification"]!({ payload: JSON.stringify(payload) });
    return { io, trigger };
  }

  it("does not emit when readNotification returns null (row not found)", async () => {
    const { io, trigger } = await setup();
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ unread_count: "2" }] })
      .mockResolvedValueOnce({ rows: [] });
    trigger({ action: "created", notification_id: "n-1", user_id: "u-1" });
    await flush();
    expect(io._emit).not.toHaveBeenCalled();
  });

  it("emits 'notification_new' to the user's notification room", async () => {
    const { io, trigger } = await setup();
    const row = makeRow();
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ unread_count: "3" }] })
      .mockResolvedValueOnce({ rows: [row] });
    trigger({ action: "created", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    expect(io.to).toHaveBeenCalledWith("notifications:user:user-1");
    expect(io._emit).toHaveBeenCalledWith("notification_new", expect.any(Object));
  });

  it("includes the unread count in the notification_new payload", async () => {
    const { io, trigger } = await setup();
    const row = makeRow();
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ unread_count: "5" }] })
      .mockResolvedValueOnce({ rows: [row] });
    trigger({ action: "created", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    const [, payload] = io._emit.mock.calls[0] as [string, { unread_count: number }];
    expect(payload.unread_count).toBe(5);
  });

  it("serializes created_at as an ISO string in the notification object", async () => {
    const { io, trigger } = await setup();
    const row = makeRow({ created_at: new Date("2026-06-15T12:00:00.000Z") });
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ unread_count: "1" }] })
      .mockResolvedValueOnce({ rows: [row] });
    trigger({ action: "created", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    const [, payload] = io._emit.mock.calls[0] as [string, { notification: { created_at: string } }];
    expect(payload.notification.created_at).toBe("2026-06-15T12:00:00.000Z");
  });

  it("sets read_at to null when the notification is unread", async () => {
    const { io, trigger } = await setup();
    const row = makeRow({ read_at: null });
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ unread_count: "0" }] })
      .mockResolvedValueOnce({ rows: [row] });
    trigger({ action: "created", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    const [, payload] = io._emit.mock.calls[0] as [string, { notification: { read_at: unknown } }];
    expect(payload.notification.read_at).toBeNull();
  });

  it("serializes read_at as an ISO string when the notification has been read", async () => {
    const { io, trigger } = await setup();
    const readAt = new Date("2026-06-16T08:00:00.000Z");
    const row = makeRow({ is_read: true, read_at: readAt });
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ unread_count: "0" }] })
      .mockResolvedValueOnce({ rows: [row] });
    trigger({ action: "created", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    const [, payload] = io._emit.mock.calls[0] as [string, { notification: { read_at: string } }];
    expect(payload.notification.read_at).toBe("2026-06-16T08:00:00.000Z");
  });

  it("does not expose event_key or user_id in the serialized notification", async () => {
    const { io, trigger } = await setup();
    const row = makeRow();
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ unread_count: "0" }] })
      .mockResolvedValueOnce({ rows: [row] });
    trigger({ action: "created", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    const [, payload] = io._emit.mock.calls[0] as [string, { notification: Record<string, unknown> }];
    expect(payload.notification).not.toHaveProperty("event_key");
    expect(payload.notification).not.toHaveProperty("user_id");
  });

  it("logs an error when publishChange rejects", async () => {
    const { trigger } = await setup();
    mockPool.query.mockRejectedValue(new Error("db error"));
    trigger({ action: "created", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    expect(mockLogger.error).toHaveBeenCalledWith(
      expect.objectContaining({ notificationId: "notif-1" }),
      "Notification realtime publish failed.",
    );
  });
});

describe("publishChange — action: read_state_changed", () => {
  async function setup() {
    process.env["DATABASE_URL"] = "postgresql://localhost/test";
    const handlers = captureClientHandlers();
    const io = makeIo();
    await startNotificationDelivery(io as never);
    const trigger = (payload: object) =>
      handlers["notification"]!({ payload: JSON.stringify(payload) });
    return { io, trigger };
  }

  it("emits 'notifications_unread_count' to the user room", async () => {
    const { io, trigger } = await setup();
    mockPool.query.mockResolvedValueOnce({ rows: [{ unread_count: "5" }] });
    trigger({ action: "read_state_changed", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    expect(io.to).toHaveBeenCalledWith("notifications:user:user-1");
    expect(io._emit).toHaveBeenCalledWith("notifications_unread_count", { unread_count: 5 });
  });

  it("does not call readNotification (only one pool query for unread count)", async () => {
    const { trigger } = await setup();
    mockPool.query.mockResolvedValueOnce({ rows: [{ unread_count: "2" }] });
    trigger({ action: "read_state_changed", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    expect(mockPool.query).toHaveBeenCalledTimes(1);
  });

  it("uses zero as unread count when the count row is missing", async () => {
    const { io, trigger } = await setup();
    mockPool.query.mockResolvedValueOnce({ rows: [] });
    trigger({ action: "read_state_changed", notification_id: "notif-1", user_id: "user-1" });
    await flush();
    const [, payload] = io._emit.mock.calls[0] as [string, { unread_count: number }];
    expect(payload.unread_count).toBe(0);
  });
});
