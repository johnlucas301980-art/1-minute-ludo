import { describe, expect, it } from "vitest";

import {
  InvalidEntryFeeError,
  InvalidPlayerCountError,
  PLATFORM_FEE_RATE,
  SUPPORTED_PLAYER_COUNTS,
  settle,
  type SettlementResult,
} from "./settlement.service";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function expectValidResult(result: SettlementResult, entryFee: number, playerCount: number) {
  expect(result.entryFee).toBe(entryFee);
  expect(result.playerCount).toBe(playerCount);
  expect(result.totalPool).toBe(entryFee * playerCount);
  expect(result.platformFee).toBe(0);
  expect(result.winnerReward).toBe(result.totalPool);
  expect(result.netReward).toBe(result.winnerReward);
}

// ---------------------------------------------------------------------------
// settle — 2 players
// ---------------------------------------------------------------------------

describe("settle — 2 players", () => {
  it("returns the correct totalPool (entryFee × 2)", () => {
    const result = settle(100, 2);
    expect(result.totalPool).toBe(200);
  });

  it("platformFee is always 0", () => {
    const result = settle(100, 2);
    expect(result.platformFee).toBe(0);
  });

  it("winnerReward equals totalPool", () => {
    const result = settle(100, 2);
    expect(result.winnerReward).toBe(result.totalPool);
  });

  it("netReward equals winnerReward", () => {
    const result = settle(100, 2);
    expect(result.netReward).toBe(result.winnerReward);
  });

  it("preserves entryFee and playerCount in the result", () => {
    const result = settle(50, 2);
    expect(result.entryFee).toBe(50);
    expect(result.playerCount).toBe(2);
  });
});

// ---------------------------------------------------------------------------
// settle — 3 players
// ---------------------------------------------------------------------------

describe("settle — 3 players", () => {
  it("returns the correct totalPool (entryFee × 3)", () => {
    const result = settle(100, 3);
    expect(result.totalPool).toBe(300);
  });

  it("platformFee is always 0", () => {
    const result = settle(100, 3);
    expect(result.platformFee).toBe(0);
  });

  it("winnerReward equals totalPool", () => {
    const result = settle(100, 3);
    expect(result.winnerReward).toBe(result.totalPool);
  });

  it("netReward equals winnerReward", () => {
    const result = settle(100, 3);
    expect(result.netReward).toBe(result.winnerReward);
  });

  it("preserves entryFee and playerCount in the result", () => {
    const result = settle(75, 3);
    expect(result.entryFee).toBe(75);
    expect(result.playerCount).toBe(3);
  });
});

// ---------------------------------------------------------------------------
// settle — 4 players
// ---------------------------------------------------------------------------

describe("settle — 4 players", () => {
  it("returns the correct totalPool (entryFee × 4)", () => {
    const result = settle(100, 4);
    expect(result.totalPool).toBe(400);
  });

  it("platformFee is always 0", () => {
    const result = settle(100, 4);
    expect(result.platformFee).toBe(0);
  });

  it("winnerReward equals totalPool", () => {
    const result = settle(100, 4);
    expect(result.winnerReward).toBe(result.totalPool);
  });

  it("netReward equals winnerReward", () => {
    const result = settle(100, 4);
    expect(result.netReward).toBe(result.winnerReward);
  });

  it("preserves entryFee and playerCount in the result", () => {
    const result = settle(25, 4);
    expect(result.entryFee).toBe(25);
    expect(result.playerCount).toBe(4);
  });
});

// ---------------------------------------------------------------------------
// settle — decimal entry fees
// ---------------------------------------------------------------------------

describe("settle — decimal entry fees", () => {
  it("handles a decimal entry fee with 2 players", () => {
    const result = settle(10.5, 2);
    expectValidResult(result, 10.5, 2);
    expect(result.totalPool).toBeCloseTo(21, 5);
  });

  it("handles a decimal entry fee with 3 players", () => {
    const result = settle(33.33, 3);
    expectValidResult(result, 33.33, 3);
    expect(result.totalPool).toBeCloseTo(99.99, 5);
  });

  it("handles a decimal entry fee with 4 players", () => {
    const result = settle(12.25, 4);
    expectValidResult(result, 12.25, 4);
    expect(result.totalPool).toBeCloseTo(49, 5);
  });
});

// ---------------------------------------------------------------------------
// settle — large entry fees
// ---------------------------------------------------------------------------

describe("settle — large entry fees", () => {
  it("correctly settles a large entry fee for 2 players", () => {
    const result = settle(10_000, 2);
    expectValidResult(result, 10_000, 2);
    expect(result.totalPool).toBe(20_000);
  });

  it("correctly settles a large entry fee for 4 players", () => {
    const result = settle(5_000, 4);
    expectValidResult(result, 5_000, 4);
    expect(result.totalPool).toBe(20_000);
  });
});

// ---------------------------------------------------------------------------
// settle — validation
// ---------------------------------------------------------------------------

describe("settle — validation", () => {
  it("throws InvalidPlayerCountError for playerCount = 1", () => {
    expect(() => settle(100, 1)).toThrow(InvalidPlayerCountError);
    expect(() => settle(100, 1)).toThrow(/Invalid player count: 1/);
  });

  it("throws InvalidPlayerCountError for playerCount = 5", () => {
    expect(() => settle(100, 5)).toThrow(InvalidPlayerCountError);
    expect(() => settle(100, 5)).toThrow(/Invalid player count: 5/);
  });

  it("throws InvalidPlayerCountError for playerCount = 0", () => {
    expect(() => settle(100, 0)).toThrow(InvalidPlayerCountError);
  });

  it("throws InvalidEntryFeeError for a negative entry fee", () => {
    expect(() => settle(-10, 2)).toThrow(InvalidEntryFeeError);
    expect(() => settle(-10, 2)).toThrow(/Invalid entry fee: -10/);
  });
});

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

describe("module constants", () => {
  it("SUPPORTED_PLAYER_COUNTS contains exactly 2, 3, and 4", () => {
    expect(SUPPORTED_PLAYER_COUNTS).toEqual([2, 3, 4]);
  });

  it("PLATFORM_FEE_RATE is 0", () => {
    expect(PLATFORM_FEE_RATE).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Error classes
// ---------------------------------------------------------------------------

describe("InvalidPlayerCountError", () => {
  it("is an instance of Error with the correct name", () => {
    const err = new InvalidPlayerCountError(7);
    expect(err).toBeInstanceOf(Error);
    expect(err.name).toBe("InvalidPlayerCountError");
    expect(err.message).toMatch(/7/);
    expect(err.message).toMatch(/2, 3, 4/);
  });
});

describe("InvalidEntryFeeError", () => {
  it("is an instance of Error with the correct name", () => {
    const err = new InvalidEntryFeeError(0);
    expect(err).toBeInstanceOf(Error);
    expect(err.name).toBe("InvalidEntryFeeError");
    expect(err.message).toMatch(/0/);
    expect(err.message).toMatch(/greater than zero/);
  });
});
