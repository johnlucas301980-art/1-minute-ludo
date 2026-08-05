import { beforeEach, describe, expect, it } from "vitest";

import { settle } from "./settlement.service";
import {
  InsufficientBalanceError,
  InvalidAmountError,
  _resetForTesting,
  applySettlement,
  creditPlayer,
  debitPlayer,
  getBalance,
} from "./wallet.service";

beforeEach(() => {
  _resetForTesting();
});

// ---------------------------------------------------------------------------
// getBalance
// ---------------------------------------------------------------------------

describe("getBalance", () => {
  it("returns 0 for a player who has never been credited", () => {
    expect(getBalance("player-unknown")).toBe(0);
  });

  it("returns the current balance after a credit", () => {
    creditPlayer("p1", 100);
    expect(getBalance("p1")).toBe(100);
  });

  it("isolates balances between different players", () => {
    creditPlayer("p1", 200);
    creditPlayer("p2", 50);
    expect(getBalance("p1")).toBe(200);
    expect(getBalance("p2")).toBe(50);
  });
});

// ---------------------------------------------------------------------------
// creditPlayer
// ---------------------------------------------------------------------------

describe("creditPlayer", () => {
  it("increases the player balance and returns the new balance", () => {
    const result = creditPlayer("p1", 100);
    expect(result).toBe(100);
    expect(getBalance("p1")).toBe(100);
  });

  it("accumulates multiple credits correctly", () => {
    creditPlayer("p1", 100);
    const result = creditPlayer("p1", 50);
    expect(result).toBe(150);
    expect(getBalance("p1")).toBe(150);
  });

  it("handles a decimal amount", () => {
    const result = creditPlayer("p1", 33.33);
    expect(result).toBeCloseTo(33.33, 5);
  });

  it("handles a large amount", () => {
    const result = creditPlayer("p1", 1_000_000);
    expect(result).toBe(1_000_000);
  });

  it("throws InvalidAmountError for amount = 0", () => {
    expect(() => creditPlayer("p1", 0)).toThrow(InvalidAmountError);
    expect(() => creditPlayer("p1", 0)).toThrow(/Invalid amount: 0/);
  });

  it("throws InvalidAmountError for a negative amount", () => {
    expect(() => creditPlayer("p1", -50)).toThrow(InvalidAmountError);
    expect(() => creditPlayer("p1", -50)).toThrow(/Invalid amount: -50/);
  });

  it("does not alter the balance when an invalid amount is supplied", () => {
    creditPlayer("p1", 100);
    expect(() => creditPlayer("p1", -10)).toThrow(InvalidAmountError);
    expect(getBalance("p1")).toBe(100);
  });
});

// ---------------------------------------------------------------------------
// debitPlayer
// ---------------------------------------------------------------------------

describe("debitPlayer", () => {
  it("decreases the player balance and returns the new balance", () => {
    creditPlayer("p1", 200);
    const result = debitPlayer("p1", 75);
    expect(result).toBe(125);
    expect(getBalance("p1")).toBe(125);
  });

  it("allows debiting the exact balance (result = 0)", () => {
    creditPlayer("p1", 100);
    const result = debitPlayer("p1", 100);
    expect(result).toBe(0);
    expect(getBalance("p1")).toBe(0);
  });

  it("throws InsufficientBalanceError when balance is too low", () => {
    creditPlayer("p1", 50);
    expect(() => debitPlayer("p1", 100)).toThrow(InsufficientBalanceError);
  });

  it("InsufficientBalanceError message includes playerId, available, and requested", () => {
    creditPlayer("p1", 30);
    expect(() => debitPlayer("p1", 80)).toThrow(/p1/);
    expect(() => debitPlayer("p1", 80)).toThrow(/30/);
    expect(() => debitPlayer("p1", 80)).toThrow(/80/);
  });

  it("does not modify the balance when InsufficientBalanceError is thrown", () => {
    creditPlayer("p1", 50);
    expect(() => debitPlayer("p1", 100)).toThrow(InsufficientBalanceError);
    expect(getBalance("p1")).toBe(50);
  });

  it("prevents balance from ever going below zero", () => {
    expect(() => debitPlayer("p1", 1)).toThrow(InsufficientBalanceError);
    expect(getBalance("p1")).toBe(0);
  });

  it("throws InvalidAmountError for amount = 0", () => {
    creditPlayer("p1", 100);
    expect(() => debitPlayer("p1", 0)).toThrow(InvalidAmountError);
  });

  it("throws InvalidAmountError for a negative amount", () => {
    creditPlayer("p1", 100);
    expect(() => debitPlayer("p1", -20)).toThrow(InvalidAmountError);
  });
});

// ---------------------------------------------------------------------------
// applySettlement — 2 players
// ---------------------------------------------------------------------------

describe("applySettlement — 2 players", () => {
  it("credits the winner with netReward", () => {
    const result = settle(100, 2);
    creditPlayer("loser", 100);
    applySettlement(result, "winner", ["winner", "loser"]);
    expect(getBalance("winner")).toBe(result.netReward);
  });

  it("debits the loser by entryFee", () => {
    const result = settle(100, 2);
    creditPlayer("loser", 100);
    applySettlement(result, "winner", ["winner", "loser"]);
    expect(getBalance("loser")).toBe(0);
  });

  it("winner netReward equals totalPool (platformFee = 0)", () => {
    const result = settle(100, 2);
    creditPlayer("loser", 100);
    applySettlement(result, "winner", ["winner", "loser"]);
    expect(getBalance("winner")).toBe(result.totalPool);
  });
});

// ---------------------------------------------------------------------------
// applySettlement — 3 players
// ---------------------------------------------------------------------------

describe("applySettlement — 3 players", () => {
  it("credits the winner with netReward", () => {
    const result = settle(50, 3);
    creditPlayer("p2", 50);
    creditPlayer("p3", 50);
    applySettlement(result, "p1", ["p1", "p2", "p3"]);
    expect(getBalance("p1")).toBe(result.netReward); // 150
  });

  it("debits all losers by entryFee", () => {
    const result = settle(50, 3);
    creditPlayer("p2", 50);
    creditPlayer("p3", 50);
    applySettlement(result, "p1", ["p1", "p2", "p3"]);
    expect(getBalance("p2")).toBe(0);
    expect(getBalance("p3")).toBe(0);
  });

  it("total debited from losers equals winner netReward (zero-sum)", () => {
    const result = settle(75, 3);
    creditPlayer("p2", 75);
    creditPlayer("p3", 75);
    const winnerCredit = result.netReward;
    const totalDebited = result.entryFee * 2;
    expect(winnerCredit).toBe(totalDebited + result.entryFee);
  });
});

// ---------------------------------------------------------------------------
// applySettlement — 4 players
// ---------------------------------------------------------------------------

describe("applySettlement — 4 players", () => {
  it("credits the winner with netReward", () => {
    const result = settle(25, 4);
    creditPlayer("p2", 25);
    creditPlayer("p3", 25);
    creditPlayer("p4", 25);
    applySettlement(result, "p1", ["p1", "p2", "p3", "p4"]);
    expect(getBalance("p1")).toBe(result.netReward); // 100
  });

  it("debits all three losers by entryFee", () => {
    const result = settle(25, 4);
    creditPlayer("p2", 25);
    creditPlayer("p3", 25);
    creditPlayer("p4", 25);
    applySettlement(result, "p1", ["p1", "p2", "p3", "p4"]);
    expect(getBalance("p2")).toBe(0);
    expect(getBalance("p3")).toBe(0);
    expect(getBalance("p4")).toBe(0);
  });

  it("winner netReward equals totalPool (platformFee = 0)", () => {
    const result = settle(25, 4);
    expect(result.netReward).toBe(100);
    expect(result.platformFee).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// applySettlement — validation
// ---------------------------------------------------------------------------

describe("applySettlement — validation", () => {
  it("throws InsufficientBalanceError when a loser cannot cover their entry fee", () => {
    const result = settle(100, 2);
    creditPlayer("loser", 50); // only 50, needs 100
    expect(() => applySettlement(result, "winner", ["winner", "loser"])).toThrow(
      InsufficientBalanceError,
    );
  });

  it("does not credit winner when a loser has insufficient balance", () => {
    const result = settle(100, 2);
    creditPlayer("loser", 50);
    expect(() => applySettlement(result, "winner", ["winner", "loser"])).toThrow();
    expect(getBalance("winner")).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Error classes
// ---------------------------------------------------------------------------

describe("InsufficientBalanceError", () => {
  it("is an instance of Error with the correct name", () => {
    const err = new InsufficientBalanceError("p1", 10, 50);
    expect(err).toBeInstanceOf(Error);
    expect(err.name).toBe("InsufficientBalanceError");
    expect(err.message).toMatch(/p1/);
    expect(err.message).toMatch(/10/);
    expect(err.message).toMatch(/50/);
  });
});

describe("InvalidAmountError", () => {
  it("is an instance of Error with the correct name", () => {
    const err = new InvalidAmountError(-5);
    expect(err).toBeInstanceOf(Error);
    expect(err.name).toBe("InvalidAmountError");
    expect(err.message).toMatch(/-5/);
    expect(err.message).toMatch(/greater than zero/);
  });
});
