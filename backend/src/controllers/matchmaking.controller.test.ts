import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const { getEntry, isQueued, queueSize } = vi.hoisted(() => ({
  getEntry: vi.fn(),
  isQueued: vi.fn(),
  queueSize: vi.fn(),
}));

vi.mock("../services/matchmaking.queue.js", () => ({ getEntry, isQueued, queueSize }));

import { getQueueStatus } from "./matchmaking.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq(userId = "user-1"): Request {
  return { user: { id: userId } } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("getQueueStatus", () => {
  it("returns inQueue: false and joinedAt: null when player is not in queue", () => {
    isQueued.mockReturnValue(false);
    getEntry.mockReturnValue(undefined);
    queueSize.mockReturnValue(3);

    const res = makeRes();
    getQueueStatus(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { inQueue: false, joinedAt: null, queueSize: 3 },
    });
  });

  it("returns inQueue: true and joinedAt ISO string when player is queued", () => {
    const joinedAt = new Date("2026-01-15T10:00:00.000Z");
    isQueued.mockReturnValue(true);
    getEntry.mockReturnValue({ joinedAt });
    queueSize.mockReturnValue(2);

    const res = makeRes();
    getQueueStatus(makeReq(), res);

    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { inQueue: true, joinedAt: joinedAt.toISOString(), queueSize: 2 },
    });
  });

  it("passes the authenticated user id to getEntry and isQueued", () => {
    isQueued.mockReturnValue(false);
    getEntry.mockReturnValue(undefined);
    queueSize.mockReturnValue(0);

    getQueueStatus(makeReq("user-xyz"), makeRes());

    expect(isQueued).toHaveBeenCalledWith("user-xyz");
    expect(getEntry).toHaveBeenCalledWith("user-xyz");
  });

  it("reflects the live queue size in the response", () => {
    isQueued.mockReturnValue(false);
    getEntry.mockReturnValue(undefined);
    queueSize.mockReturnValue(7);

    const res = makeRes();
    getQueueStatus(makeReq(), res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ queueSize: 7 }) }),
    );
  });
});
