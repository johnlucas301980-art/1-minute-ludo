import { beforeEach, describe, expect, it } from "vitest";
import {
  dequeue,
  dequeueOpponent,
  enqueue,
  getEntry,
  isQueued,
  queueSize,
  removeStaleEntries,
} from "./matchmaking.queue.js";

const entry = (userId: string, joinedAt = new Date()): Parameters<typeof enqueue>[0] => ({
  userId,
  playerId: `player-${userId}`,
  fullName: `Player ${userId}`,
  avatar: null,
  socketId: `socket-${userId}`,
  joinedAt,
});

beforeEach(() => {
  for (const userId of ["user-a", "user-b", "user-c", "user-d", "user-e"]) {
    dequeue(userId);
  }
});

describe("matchmaking queue", () => {
  it("adds and retrieves a player entry", () => {
    const player = entry("user-a");

    enqueue(player);

    expect(getEntry("user-a")).toEqual(player);
    expect(isQueued("user-a")).toBe(true);
    expect(queueSize()).toBe(1);
  });

  it("replaces an existing player entry by user ID", () => {
    enqueue(entry("user-a", new Date("2026-01-01T00:00:00Z")));
    const replacement = entry("user-a", new Date("2026-01-02T00:00:00Z"));

    enqueue(replacement);

    expect(getEntry("user-a")).toEqual(replacement);
    expect(queueSize()).toBe(1);
  });

  it("dequeues a player and reports whether removal occurred", () => {
    enqueue(entry("user-a"));

    expect(dequeue("user-a")).toBe(true);
    expect(dequeue("user-a")).toBe(false);
    expect(isQueued("user-a")).toBe(false);
    expect(queueSize()).toBe(0);
  });

  it("dequeues the first opponent while leaving the excluded player queued", () => {
    const first = entry("user-a");
    const second = entry("user-b");
    enqueue(first);
    enqueue(second);

    expect(dequeueOpponent("user-a")).toEqual(second);
    expect(isQueued("user-a")).toBe(true);
    expect(isQueued("user-b")).toBe(false);
  });

  it("returns no opponent when only the excluded player is queued", () => {
    enqueue(entry("user-a"));

    expect(dequeueOpponent("user-a")).toBeUndefined();
    expect(queueSize()).toBe(1);
  });

  it("removes entries older than the requested maximum age", () => {
    const now = Date.now();
    enqueue(entry("user-a", new Date(now - 10_000)));
    enqueue(entry("user-b", new Date(now - 1_000)));

    expect(removeStaleEntries(5_000)).toBe(1);
    expect(isQueued("user-a")).toBe(false);
    expect(isQueued("user-b")).toBe(true);
  });

  it("keeps entries at or newer than the cutoff", () => {
    enqueue(entry("user-a", new Date()));

    expect(removeStaleEntries(60_000)).toBe(0);
    expect(isQueued("user-a")).toBe(true);
  });
});