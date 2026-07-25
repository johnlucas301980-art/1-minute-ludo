import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const {
  findOrCreateWallet,
  getTransactions,
  depositPoints,
  withdrawPoints,
  InsufficientBalanceError,
} = vi.hoisted(() => {
  class InsufficientBalanceError extends Error {
    constructor(available: number, requested: number) {
      super(`Insufficient balance: available ${available}, requested ${requested}.`);
      this.name = "InsufficientBalanceError";
    }
  }
  return {
    findOrCreateWallet: vi.fn(),
    getTransactions: vi.fn(),
    depositPoints: vi.fn(),
    withdrawPoints: vi.fn(),
    InsufficientBalanceError,
  };
});

vi.mock("../services/wallet.service.js", () => ({
  findOrCreateWallet,
  getTransactions,
  depositPoints,
  withdrawPoints,
  InsufficientBalanceError,
}));
vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import { getWallet, getWalletHistory, deposit, withdraw } from "./wallet.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq({
  userId = "user-1",
  query = {} as Record<string, string>,
  body = {} as Record<string, unknown>,
} = {}): Request {
  return {
    log: { error: vi.fn() },
    user: { id: userId },
    query,
    body,
  } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

function makeWallet(overrides = {}) {
  return {
    id: "wallet-1",
    user_id: "user-1",
    points: "100.00",
    total_deposit: "200.00",
    total_withdraw: "100.00",
    updated_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

function makeTransaction(overrides = {}) {
  return {
    id: "tx-1",
    user_id: "user-1",
    type: "deposit",
    amount: "50.00",
    status: "completed",
    reference: null,
    created_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// getWallet
// ---------------------------------------------------------------------------

describe("getWallet", () => {
  it("returns 200 with wallet data", async () => {
    const wallet = makeWallet();
    findOrCreateWallet.mockResolvedValue(wallet);

    const res = makeRes();
    await getWallet(makeReq(), res);

    expect(findOrCreateWallet).toHaveBeenCalledWith("user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        wallet: {
          id: wallet.id,
          points: 100,
          total_deposit: 200,
          total_withdraw: 100,
          updated_at: wallet.updated_at,
        },
      },
    });
  });

  it("converts string numeric fields to floats", async () => {
    findOrCreateWallet.mockResolvedValue(makeWallet({ points: "12.50", total_deposit: "99.99", total_withdraw: "87.49" }));

    const res = makeRes();
    await getWallet(makeReq(), res);

    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0] as {
      data: { wallet: { points: number; total_deposit: number; total_withdraw: number } };
    };
    expect(body.data.wallet.points).toBe(12.5);
    expect(body.data.wallet.total_deposit).toBe(99.99);
    expect(body.data.wallet.total_withdraw).toBe(87.49);
  });

  it("returns 500 when findOrCreateWallet throws", async () => {
    findOrCreateWallet.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getWallet(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// getWalletHistory
// ---------------------------------------------------------------------------

describe("getWalletHistory", () => {
  it("returns 200 with transactions using default pagination", async () => {
    const tx = makeTransaction();
    getTransactions.mockResolvedValue([tx]);

    const res = makeRes();
    await getWalletHistory(makeReq(), res);

    expect(getTransactions).toHaveBeenCalledWith("user-1", 20, 0);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        transactions: [
          {
            id: tx.id,
            type: tx.type,
            amount: 50,
            status: tx.status,
            reference: tx.reference,
            created_at: tx.created_at,
          },
        ],
        pagination: { limit: 20, offset: 0, count: 1 },
      },
    });
  });

  it("forwards valid limit and offset to the service", async () => {
    getTransactions.mockResolvedValue([]);

    await getWalletHistory(makeReq({ query: { limit: "10", offset: "5" } }), makeRes());

    expect(getTransactions).toHaveBeenCalledWith("user-1", 10, 5);
  });

  it("clamps limit above 100 to 100", async () => {
    getTransactions.mockResolvedValue([]);

    await getWalletHistory(makeReq({ query: { limit: "200" } }), makeRes());

    expect(getTransactions).toHaveBeenCalledWith("user-1", 100, 0);
  });

  it("falls back to default limit when limit is non-numeric", async () => {
    getTransactions.mockResolvedValue([]);

    await getWalletHistory(makeReq({ query: { limit: "abc" } }), makeRes());

    expect(getTransactions).toHaveBeenCalledWith("user-1", 20, 0);
  });

  it("clamps negative offset to 0 silently", async () => {
    getTransactions.mockResolvedValue([]);

    await getWalletHistory(makeReq({ query: { offset: "-10" } }), makeRes());

    expect(getTransactions).toHaveBeenCalledWith("user-1", 20, 0);
  });

  it("returns 500 when getTransactions throws", async () => {
    getTransactions.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getWalletHistory(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// deposit
// ---------------------------------------------------------------------------

describe("deposit", () => {
  it("returns 200 with wallet and transaction on success", async () => {
    const wallet = makeWallet({ points: "150.00", total_deposit: "250.00" });
    const tx = makeTransaction({ type: "deposit", amount: "50.00" });
    depositPoints.mockResolvedValue({ wallet, transaction: tx });

    const res = makeRes();
    await deposit(makeReq({ body: { amount: 50 } }), res);

    expect(depositPoints).toHaveBeenCalledWith("user-1", 50, undefined);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        wallet: expect.objectContaining({ id: wallet.id, points: 150 }),
        transaction: expect.objectContaining({ id: tx.id, amount: 50 }),
      },
    });
  });

  it("passes an optional reference to depositPoints", async () => {
    const wallet = makeWallet();
    const tx = makeTransaction({ reference: "ref-123" });
    depositPoints.mockResolvedValue({ wallet, transaction: tx });

    await deposit(makeReq({ body: { amount: 25, reference: "ref-123" } }), makeRes());

    expect(depositPoints).toHaveBeenCalledWith("user-1", 25, "ref-123");
  });

  it("returns 400 when amount is missing", async () => {
    const res = makeRes();
    await deposit(makeReq({ body: {} }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "amount is required." });
    expect(depositPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is zero", async () => {
    const res = makeRes();
    await deposit(makeReq({ body: { amount: 0 } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(depositPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is negative", async () => {
    const res = makeRes();
    await deposit(makeReq({ body: { amount: -10 } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(depositPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is non-numeric", async () => {
    const res = makeRes();
    await deposit(makeReq({ body: { amount: "abc" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(depositPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when amount exceeds maximum (1_000_000)", async () => {
    const res = makeRes();
    await deposit(makeReq({ body: { amount: 1_000_001 } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(depositPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when reference exceeds 255 characters", async () => {
    const res = makeRes();
    await deposit(makeReq({ body: { amount: 10, reference: "x".repeat(256) } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(depositPoints).not.toHaveBeenCalled();
  });

  it("strips whitespace-only reference and treats it as undefined", async () => {
    const wallet = makeWallet();
    const tx = makeTransaction();
    depositPoints.mockResolvedValue({ wallet, transaction: tx });

    await deposit(makeReq({ body: { amount: 10, reference: "   " } }), makeRes());

    expect(depositPoints).toHaveBeenCalledWith("user-1", 10, undefined);
  });

  it("returns 500 when depositPoints throws", async () => {
    depositPoints.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await deposit(makeReq({ body: { amount: 10 } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// withdraw
// ---------------------------------------------------------------------------

describe("withdraw", () => {
  it("returns 200 with wallet and transaction on success", async () => {
    const wallet = makeWallet({ points: "50.00", total_withdraw: "150.00" });
    const tx = makeTransaction({ type: "withdraw", amount: "50.00" });
    withdrawPoints.mockResolvedValue({ wallet, transaction: tx });

    const res = makeRes();
    await withdraw(makeReq({ body: { amount: 50 } }), res);

    expect(withdrawPoints).toHaveBeenCalledWith("user-1", 50, undefined);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        wallet: expect.objectContaining({ id: wallet.id, points: 50 }),
        transaction: expect.objectContaining({ id: tx.id, amount: 50 }),
      },
    });
  });

  it("passes an optional reference to withdrawPoints", async () => {
    const wallet = makeWallet();
    const tx = makeTransaction({ reference: "ref-456" });
    withdrawPoints.mockResolvedValue({ wallet, transaction: tx });

    await withdraw(makeReq({ body: { amount: 25, reference: "ref-456" } }), makeRes());

    expect(withdrawPoints).toHaveBeenCalledWith("user-1", 25, "ref-456");
  });

  it("returns 400 when amount is missing", async () => {
    const res = makeRes();
    await withdraw(makeReq({ body: {} }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "amount is required." });
    expect(withdrawPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is zero", async () => {
    const res = makeRes();
    await withdraw(makeReq({ body: { amount: 0 } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(withdrawPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is negative", async () => {
    const res = makeRes();
    await withdraw(makeReq({ body: { amount: -5 } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(withdrawPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when amount exceeds maximum (1_000_000)", async () => {
    const res = makeRes();
    await withdraw(makeReq({ body: { amount: 1_000_001 } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(withdrawPoints).not.toHaveBeenCalled();
  });

  it("returns 400 when reference exceeds 255 characters", async () => {
    const res = makeRes();
    await withdraw(makeReq({ body: { amount: 10, reference: "y".repeat(256) } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(withdrawPoints).not.toHaveBeenCalled();
  });

  it("returns 422 when withdrawPoints throws InsufficientBalanceError", async () => {
    withdrawPoints.mockRejectedValue(new InsufficientBalanceError(10, 50));

    const res = makeRes();
    await withdraw(makeReq({ body: { amount: 50 } }), res);

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Insufficient balance.",
    });
  });

  it("returns 500 when withdrawPoints throws a generic error", async () => {
    withdrawPoints.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await withdraw(makeReq({ body: { amount: 10 } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
