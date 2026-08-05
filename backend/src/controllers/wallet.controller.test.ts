import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const {
  getBalance,
  creditPlayer,
  debitPlayer,
  InsufficientBalanceError,
  InvalidAmountError,
} = vi.hoisted(() => {
  class InsufficientBalanceError extends Error {
    constructor(playerId: string, available: number, requested: number) {
      super(`Insufficient balance for player "${playerId}": available ${available}, requested ${requested}.`);
      this.name = "InsufficientBalanceError";
    }
  }
  class InvalidAmountError extends Error {
    constructor(amount: number) {
      super(`Invalid amount: ${amount}. Amount must be greater than zero.`);
      this.name = "InvalidAmountError";
    }
  }
  return {
    getBalance: vi.fn<(playerId: string) => number>(),
    creditPlayer: vi.fn<(playerId: string, amount: number) => number>(),
    debitPlayer: vi.fn<(playerId: string, amount: number) => number>(),
    InsufficientBalanceError,
    InvalidAmountError,
  };
});

const { createTransaction, getPlayerTransactions } = vi.hoisted(() => ({
  createTransaction: vi.fn(),
  getPlayerTransactions: vi.fn(),
}));

vi.mock("../services/wallet.service.js", () => ({
  getBalance,
  creditPlayer,
  debitPlayer,
  InsufficientBalanceError,
  InvalidAmountError,
}));

vi.mock("../services/transaction_service.js", () => ({
  createTransaction,
  getPlayerTransactions,
}));

import {
  getWalletBalance,
  getWalletTransactions,
  requestRecharge,
  requestWithdraw,
} from "./wallet.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq({
  params = {} as Record<string, string>,
  body = {} as Record<string, unknown>,
} = {}): Request {
  return { params, body } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

function makeTx(overrides = {}) {
  return {
    transactionId: "tx-1",
    playerId: "player-1",
    type: "Recharge",
    amount: 100,
    balanceBefore: 0,
    balanceAfter: 100,
    createdAt: new Date("2026-01-01T00:00:00Z"),
    referenceId: undefined,
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// getWalletBalance
// ---------------------------------------------------------------------------

describe("getWalletBalance", () => {
  it("returns 200 with playerId and balance", () => {
    getBalance.mockReturnValue(250);
    const res = makeRes();
    getWalletBalance(makeReq({ params: { playerId: "player-1" } }), res);
    expect(getBalance).toHaveBeenCalledWith("player-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { playerId: "player-1", balance: 250 },
    });
  });

  it("returns 200 with balance 0 for a player with no history", () => {
    getBalance.mockReturnValue(0);
    const res = makeRes();
    getWalletBalance(makeReq({ params: { playerId: "new-player" } }), res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { playerId: "new-player", balance: 0 },
    });
  });

  it("returns 400 when playerId param is an empty string", () => {
    const res = makeRes();
    getWalletBalance(makeReq({ params: { playerId: "" } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "playerId is required." });
    expect(getBalance).not.toHaveBeenCalled();
  });

  it("returns 400 when playerId param is whitespace only", () => {
    const res = makeRes();
    getWalletBalance(makeReq({ params: { playerId: "   " } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(getBalance).not.toHaveBeenCalled();
  });
});

// ---------------------------------------------------------------------------
// getWalletTransactions
// ---------------------------------------------------------------------------

describe("getWalletTransactions", () => {
  it("returns 200 with transaction list for a player with history", () => {
    const tx = makeTx();
    getPlayerTransactions.mockReturnValue([tx]);
    const res = makeRes();
    getWalletTransactions(makeReq({ params: { playerId: "player-1" } }), res);
    expect(getPlayerTransactions).toHaveBeenCalledWith("player-1");
    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.data.playerId).toBe("player-1");
    expect(body.data.transactions).toHaveLength(1);
  });

  it("returns 200 with empty transactions array for a player with no history", () => {
    getPlayerTransactions.mockReturnValue([]);
    const res = makeRes();
    getWalletTransactions(makeReq({ params: { playerId: "player-1" } }), res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { playerId: "player-1", transactions: [] },
    });
  });

  it("serialises all transaction fields in the response", () => {
    const tx = makeTx({ referenceId: "ref-99" });
    getPlayerTransactions.mockReturnValue([tx]);
    const res = makeRes();
    getWalletTransactions(makeReq({ params: { playerId: "player-1" } }), res);
    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0];
    const out = body.data.transactions[0];
    expect(out.transactionId).toBe("tx-1");
    expect(out.type).toBe("Recharge");
    expect(out.amount).toBe(100);
    expect(out.balanceBefore).toBe(0);
    expect(out.balanceAfter).toBe(100);
    expect(out.referenceId).toBe("ref-99");
    expect(out.createdAt).toBeDefined();
  });

  it("calls getPlayerTransactions with the correct playerId", () => {
    getPlayerTransactions.mockReturnValue([]);
    getWalletTransactions(makeReq({ params: { playerId: "player-xyz" } }), makeRes());
    expect(getPlayerTransactions).toHaveBeenCalledWith("player-xyz");
  });

  it("returns 400 when playerId param is empty", () => {
    const res = makeRes();
    getWalletTransactions(makeReq({ params: { playerId: "" } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(getPlayerTransactions).not.toHaveBeenCalled();
  });
});

// ---------------------------------------------------------------------------
// requestRecharge
// ---------------------------------------------------------------------------

describe("requestRecharge", () => {
  it("returns 200 with a serialised Recharge transaction on success", () => {
    getBalance.mockReturnValueOnce(0).mockReturnValueOnce(100);
    creditPlayer.mockReturnValue(100);
    const tx = makeTx({ type: "Recharge" });
    createTransaction.mockReturnValue(tx);

    const res = makeRes();
    requestRecharge(makeReq({ body: { playerId: "player-1", amount: 100 } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.data.transaction.type).toBe("Recharge");
    expect(body.data.transaction.transactionId).toBe("tx-1");
  });

  it("calls creditPlayer with the correct playerId and amount", () => {
    getBalance.mockReturnValue(0);
    creditPlayer.mockReturnValue(50);
    createTransaction.mockReturnValue(makeTx({ amount: 50 }));

    requestRecharge(makeReq({ body: { playerId: "player-1", amount: 50 } }), makeRes());

    expect(creditPlayer).toHaveBeenCalledWith("player-1", 50);
  });

  it("passes balanceBefore and balanceAfter to createTransaction", () => {
    getBalance.mockReturnValueOnce(200).mockReturnValueOnce(300);
    creditPlayer.mockReturnValue(300);
    createTransaction.mockReturnValue(makeTx());

    requestRecharge(makeReq({ body: { playerId: "player-1", amount: 100 } }), makeRes());

    expect(createTransaction).toHaveBeenCalledWith(
      expect.objectContaining({ balanceBefore: 200, balanceAfter: 300, type: "Recharge" }),
    );
  });

  it("passes referenceId to createTransaction when provided", () => {
    getBalance.mockReturnValue(0);
    creditPlayer.mockReturnValue(100);
    createTransaction.mockReturnValue(makeTx({ referenceId: "ref-abc" }));

    requestRecharge(
      makeReq({ body: { playerId: "player-1", amount: 100, referenceId: "ref-abc" } }),
      makeRes(),
    );

    expect(createTransaction).toHaveBeenCalledWith(
      expect.objectContaining({ referenceId: "ref-abc" }),
    );
  });

  it("passes referenceId as undefined when not provided", () => {
    getBalance.mockReturnValue(0);
    creditPlayer.mockReturnValue(100);
    createTransaction.mockReturnValue(makeTx());

    requestRecharge(makeReq({ body: { playerId: "player-1", amount: 100 } }), makeRes());

    expect(createTransaction).toHaveBeenCalledWith(
      expect.objectContaining({ referenceId: undefined }),
    );
  });

  it("returns 400 when playerId is missing", () => {
    const res = makeRes();
    requestRecharge(makeReq({ body: { amount: 100 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "playerId is required." });
    expect(creditPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is missing", () => {
    const res = makeRes();
    requestRecharge(makeReq({ body: { playerId: "player-1" } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "amount is required." });
    expect(creditPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is zero", () => {
    const res = makeRes();
    requestRecharge(makeReq({ body: { playerId: "player-1", amount: 0 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(creditPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is negative", () => {
    const res = makeRes();
    requestRecharge(makeReq({ body: { playerId: "player-1", amount: -50 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(creditPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is non-numeric", () => {
    const res = makeRes();
    requestRecharge(makeReq({ body: { playerId: "player-1", amount: "abc" } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(creditPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount exceeds 1 000 000", () => {
    const res = makeRes();
    requestRecharge(makeReq({ body: { playerId: "player-1", amount: 1_000_001 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(creditPlayer).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error from creditPlayer", () => {
    getBalance.mockReturnValue(0);
    creditPlayer.mockImplementation(() => { throw new Error("unexpected"); });

    const res = makeRes();
    requestRecharge(makeReq({ body: { playerId: "player-1", amount: 100 } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// requestWithdraw
// ---------------------------------------------------------------------------

describe("requestWithdraw", () => {
  it("returns 200 with a serialised Withdrawal transaction on success", () => {
    getBalance.mockReturnValueOnce(200).mockReturnValueOnce(100);
    debitPlayer.mockReturnValue(100);
    const tx = makeTx({ type: "Withdrawal", balanceBefore: 200, balanceAfter: 100 });
    createTransaction.mockReturnValue(tx);

    const res = makeRes();
    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 100 } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.data.transaction.type).toBe("Withdrawal");
  });

  it("calls debitPlayer with the correct playerId and amount", () => {
    getBalance.mockReturnValue(300);
    debitPlayer.mockReturnValue(200);
    createTransaction.mockReturnValue(makeTx({ type: "Withdrawal" }));

    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 100 } }), makeRes());

    expect(debitPlayer).toHaveBeenCalledWith("player-1", 100);
  });

  it("passes balanceBefore and balanceAfter to createTransaction", () => {
    getBalance.mockReturnValueOnce(500).mockReturnValueOnce(400);
    debitPlayer.mockReturnValue(400);
    createTransaction.mockReturnValue(makeTx({ type: "Withdrawal" }));

    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 100 } }), makeRes());

    expect(createTransaction).toHaveBeenCalledWith(
      expect.objectContaining({ balanceBefore: 500, balanceAfter: 400, type: "Withdrawal" }),
    );
  });

  it("passes referenceId to createTransaction when provided", () => {
    getBalance.mockReturnValue(200);
    debitPlayer.mockReturnValue(100);
    createTransaction.mockReturnValue(makeTx({ type: "Withdrawal", referenceId: "wd-ref" }));

    requestWithdraw(
      makeReq({ body: { playerId: "player-1", amount: 100, referenceId: "wd-ref" } }),
      makeRes(),
    );

    expect(createTransaction).toHaveBeenCalledWith(
      expect.objectContaining({ referenceId: "wd-ref" }),
    );
  });

  it("returns 400 when playerId is missing", () => {
    const res = makeRes();
    requestWithdraw(makeReq({ body: { amount: 100 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "playerId is required." });
    expect(debitPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is missing", () => {
    const res = makeRes();
    requestWithdraw(makeReq({ body: { playerId: "player-1" } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "amount is required." });
    expect(debitPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is zero", () => {
    const res = makeRes();
    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 0 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(debitPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount is negative", () => {
    const res = makeRes();
    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: -10 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(debitPlayer).not.toHaveBeenCalled();
  });

  it("returns 400 when amount exceeds 1 000 000", () => {
    const res = makeRes();
    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 1_000_001 } }), res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(debitPlayer).not.toHaveBeenCalled();
  });

  it("returns 422 when debitPlayer throws InsufficientBalanceError", () => {
    getBalance.mockReturnValue(50);
    debitPlayer.mockImplementation(() => {
      throw new InsufficientBalanceError("player-1", 50, 100);
    });

    const res = makeRes();
    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 100 } }), res);

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Insufficient balance." });
  });

  it("does not call createTransaction when InsufficientBalanceError is thrown", () => {
    getBalance.mockReturnValue(10);
    debitPlayer.mockImplementation(() => {
      throw new InsufficientBalanceError("player-1", 10, 100);
    });

    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 100 } }), makeRes());

    expect(createTransaction).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error from debitPlayer", () => {
    getBalance.mockReturnValue(500);
    debitPlayer.mockImplementation(() => { throw new Error("unexpected failure"); });

    const res = makeRes();
    requestWithdraw(makeReq({ body: { playerId: "player-1", amount: 100 } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
