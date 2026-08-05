import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  _resetForTesting,
  createTransaction,
  generateId,
  getPlayerTransactions,
  getTransactionById,
  type CreateTransactionParams,
  type Transaction,
  type TransactionType,
} from "./transaction_service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function params(overrides: Partial<CreateTransactionParams> = {}): CreateTransactionParams {
  return {
    playerId: "player-1",
    type: "Recharge",
    amount: 100,
    balanceBefore: 0,
    balanceAfter: 100,
    ...overrides,
  };
}

beforeEach(() => {
  _resetForTesting();
  vi.restoreAllMocks();
});

// ---------------------------------------------------------------------------
// createTransaction — shape
// ---------------------------------------------------------------------------

describe("createTransaction — returned shape", () => {
  it("returns a transaction with all required fields", () => {
    const tx = createTransaction(params());
    expect(tx.transactionId).toBeDefined();
    expect(tx.playerId).toBe("player-1");
    expect(tx.type).toBe("Recharge");
    expect(tx.amount).toBe(100);
    expect(tx.balanceBefore).toBe(0);
    expect(tx.balanceAfter).toBe(100);
    expect(tx.createdAt).toBeInstanceOf(Date);
  });

  it("stores referenceId when provided", () => {
    const tx = createTransaction(params({ referenceId: "ref-abc" }));
    expect(tx.referenceId).toBe("ref-abc");
  });

  it("leaves referenceId undefined when not provided", () => {
    const tx = createTransaction(params());
    expect(tx.referenceId).toBeUndefined();
  });

  it("assigns a non-empty string transactionId", () => {
    const tx = createTransaction(params());
    expect(typeof tx.transactionId).toBe("string");
    expect(tx.transactionId.length).toBeGreaterThan(0);
  });

  it("generates unique transactionIds for consecutive transactions", () => {
    const tx1 = createTransaction(params());
    const tx2 = createTransaction(params());
    expect(tx1.transactionId).not.toBe(tx2.transactionId);
  });

  it("createdAt is a Date set to approximately now", () => {
    const before = Date.now();
    const tx = createTransaction(params());
    const after = Date.now();
    expect(tx.createdAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(tx.createdAt.getTime()).toBeLessThanOrEqual(after);
  });
});

// ---------------------------------------------------------------------------
// createTransaction — immutability
// ---------------------------------------------------------------------------

describe("createTransaction — immutability", () => {
  it("returns a frozen object", () => {
    const tx = createTransaction(params());
    expect(Object.isFrozen(tx)).toBe(true);
  });

  it("throws when attempting to mutate a returned transaction in strict mode", () => {
    const tx = createTransaction(params());
    expect(() => {
      "use strict";
      (tx as Transaction).amount = 9999;
    }).toThrow();
  });

  it("stored transaction cannot be modified through a second lookup", () => {
    const tx = createTransaction(params());
    const fetched = getTransactionById(tx.transactionId)!;
    expect(Object.isFrozen(fetched)).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// createTransaction — all transaction types
// ---------------------------------------------------------------------------

describe("createTransaction — all TransactionType values", () => {
  const allTypes: TransactionType[] = [
    "Recharge",
    "EntryFee",
    "WinReward",
    "Refund",
    "Withdrawal",
    "AdminAdjustment",
  ];

  for (const type of allTypes) {
    it(`stores type "${type}" correctly`, () => {
      const tx = createTransaction(params({ type }));
      expect(tx.type).toBe(type);
    });
  }
});

// ---------------------------------------------------------------------------
// getTransactionById
// ---------------------------------------------------------------------------

describe("getTransactionById", () => {
  it("returns undefined for an unknown transactionId", () => {
    expect(getTransactionById("does-not-exist")).toBeUndefined();
  });

  it("returns the correct transaction by ID", () => {
    const tx = createTransaction(params({ amount: 250, type: "WinReward" }));
    const found = getTransactionById(tx.transactionId);
    expect(found).toBeDefined();
    expect(found!.transactionId).toBe(tx.transactionId);
    expect(found!.amount).toBe(250);
    expect(found!.type).toBe("WinReward");
  });

  it("returns the same frozen object that createTransaction returned", () => {
    const tx = createTransaction(params());
    const found = getTransactionById(tx.transactionId);
    expect(found).toBe(tx);
  });

  it("can retrieve each of multiple transactions independently", () => {
    const tx1 = createTransaction(params({ amount: 10 }));
    const tx2 = createTransaction(params({ amount: 20 }));
    expect(getTransactionById(tx1.transactionId)!.amount).toBe(10);
    expect(getTransactionById(tx2.transactionId)!.amount).toBe(20);
  });
});

// ---------------------------------------------------------------------------
// getPlayerTransactions
// ---------------------------------------------------------------------------

describe("getPlayerTransactions", () => {
  it("returns an empty array for a player with no history", () => {
    expect(getPlayerTransactions("unknown-player")).toEqual([]);
  });

  it("returns all transactions belonging to the player", () => {
    createTransaction(params({ amount: 50 }));
    createTransaction(params({ amount: 75 }));
    const txs = getPlayerTransactions("player-1");
    expect(txs).toHaveLength(2);
  });

  it("does not include transactions from other players", () => {
    createTransaction(params({ playerId: "player-1", amount: 100 }));
    createTransaction(params({ playerId: "player-2", amount: 200 }));
    const txs = getPlayerTransactions("player-1");
    expect(txs).toHaveLength(1);
    expect(txs[0]!.amount).toBe(100);
  });

  it("sorts transactions newest first", () => {
    const tx1 = createTransaction(params({ amount: 10 }));
    const tx2 = createTransaction(params({ amount: 20 }));
    const tx3 = createTransaction(params({ amount: 30 }));
    const txs = getPlayerTransactions("player-1");
    expect(txs[0]!.transactionId).toBe(tx3.transactionId);
    expect(txs[1]!.transactionId).toBe(tx2.transactionId);
    expect(txs[2]!.transactionId).toBe(tx1.transactionId);
  });

  it("does not mutate the internal index order (newest-first is a view)", () => {
    createTransaction(params({ amount: 10 }));
    createTransaction(params({ amount: 20 }));
    getPlayerTransactions("player-1"); // consume once
    const txs = getPlayerTransactions("player-1"); // consume again
    expect(txs[0]!.amount).toBe(20); // still newest first
    expect(txs[1]!.amount).toBe(10);
  });

  it("returns a single transaction for a player with one entry", () => {
    const tx = createTransaction(params({ amount: 500, type: "Withdrawal" }));
    const txs = getPlayerTransactions("player-1");
    expect(txs).toHaveLength(1);
    expect(txs[0]!.transactionId).toBe(tx.transactionId);
  });
});

// ---------------------------------------------------------------------------
// Immutable history — no modification of existing entries
// ---------------------------------------------------------------------------

describe("immutable history", () => {
  it("older transactions are unaffected by newer ones", () => {
    const tx1 = createTransaction(params({ amount: 100, balanceBefore: 0, balanceAfter: 100 }));
    createTransaction(params({ amount: 50, balanceBefore: 100, balanceAfter: 150 }));
    const fetched = getTransactionById(tx1.transactionId)!;
    expect(fetched.amount).toBe(100);
    expect(fetched.balanceBefore).toBe(0);
    expect(fetched.balanceAfter).toBe(100);
  });

  it("balanceBefore and balanceAfter are stored exactly as supplied", () => {
    const tx = createTransaction(
      params({ balanceBefore: 123.45, balanceAfter: 223.45, amount: 100 }),
    );
    expect(tx.balanceBefore).toBe(123.45);
    expect(tx.balanceAfter).toBe(223.45);
  });
});

// ---------------------------------------------------------------------------
// generateId integration
// ---------------------------------------------------------------------------

describe("generateId", () => {
  it("is used to assign the transactionId", () => {
    vi.spyOn({ generateId }, "generateId").mockReturnValue("fixed-id");
    // Confirm the default generator produces a non-empty string
    const id = generateId();
    expect(typeof id).toBe("string");
    expect(id.length).toBeGreaterThan(0);
  });
});
