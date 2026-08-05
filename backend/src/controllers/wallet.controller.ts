/**
 * Wallet controller — Step 17 (Wallet API).
 *
 * GET  /wallet/:playerId                — current balance
 * GET  /wallet/:playerId/transactions   — transaction history, newest first
 * POST /wallet/recharge/request         — credit points (no payment gateway)
 * POST /wallet/withdraw/request         — debit points  (no payment gateway)
 *
 * Uses the in-memory wallet.service and transaction_service.
 * Never exposes internal objects — all responses are plain JSON.
 */

import type { Request, Response } from "express";

import {
  InsufficientBalanceError,
  InvalidAmountError,
  creditPlayer,
  debitPlayer,
  getBalance,
} from "../services/wallet.service.js";
import {
  createTransaction,
  getPlayerTransactions,
} from "../services/transaction_service.js";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_AMOUNT = 1_000_000;

// ---------------------------------------------------------------------------
// Shared validation helpers
// ---------------------------------------------------------------------------

function parsePlayerId(raw: unknown): string | null {
  if (typeof raw !== "string" || raw.trim().length === 0) return null;
  return raw.trim();
}

function parseAmount(raw: unknown): number | null {
  if (raw === undefined || raw === null || raw === "") return null;
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0 || n > MAX_AMOUNT) return null;
  return Math.round(n * 100) / 100;
}

function parseReferenceId(raw: unknown): string | undefined {
  if (typeof raw !== "string") return undefined;
  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

/** Serialise a transaction for a response — never leaks internal fields. */
function serializeTransaction(tx: ReturnType<typeof createTransaction>) {
  return {
    transactionId: tx.transactionId,
    playerId: tx.playerId,
    type: tx.type,
    amount: tx.amount,
    balanceBefore: tx.balanceBefore,
    balanceAfter: tx.balanceAfter,
    createdAt: tx.createdAt,
    referenceId: tx.referenceId,
  };
}

// ---------------------------------------------------------------------------
// GET /wallet/:playerId
// ---------------------------------------------------------------------------

/**
 * Return the current in-memory balance for the given player.
 * Returns 0 for players who have never been credited — not an error.
 */
export function getWalletBalance(req: Request, res: Response): void {
  const playerId = parsePlayerId(req.params["playerId"]);
  if (!playerId) {
    res.status(400).json({ success: false, message: "playerId is required." });
    return;
  }

  const balance = getBalance(playerId);
  res.status(200).json({ success: true, data: { playerId, balance } });
}

// ---------------------------------------------------------------------------
// GET /wallet/:playerId/transactions
// ---------------------------------------------------------------------------

/**
 * Return the full transaction history for the given player, newest first.
 * Returns an empty array for players with no history.
 */
export function getWalletTransactions(req: Request, res: Response): void {
  const playerId = parsePlayerId(req.params["playerId"]);
  if (!playerId) {
    res.status(400).json({ success: false, message: "playerId is required." });
    return;
  }

  const transactions = getPlayerTransactions(playerId).map(serializeTransaction);
  res.status(200).json({ success: true, data: { playerId, transactions } });
}

// ---------------------------------------------------------------------------
// POST /wallet/recharge/request
// ---------------------------------------------------------------------------

/**
 * Create a recharge request: credit `amount` points to `playerId` and record
 * a Recharge transaction.  No payment gateway involved.
 *
 * Body: { playerId, amount, referenceId? }
 */
export function requestRecharge(req: Request, res: Response): void {
  const playerId = parsePlayerId(req.body["playerId"]);
  if (!playerId) {
    res.status(400).json({ success: false, message: "playerId is required." });
    return;
  }

  if (req.body["amount"] === undefined || req.body["amount"] === null || req.body["amount"] === "") {
    res.status(400).json({ success: false, message: "amount is required." });
    return;
  }

  const amount = parseAmount(req.body["amount"]);
  if (amount === null) {
    res.status(400).json({
      success: false,
      message: `amount must be a positive number not exceeding ${MAX_AMOUNT}.`,
    });
    return;
  }

  const referenceId = parseReferenceId(req.body["referenceId"]);

  try {
    const balanceBefore = getBalance(playerId);
    creditPlayer(playerId, amount);
    const balanceAfter = getBalance(playerId);

    const tx = createTransaction({
      playerId,
      type: "Recharge",
      amount,
      balanceBefore,
      balanceAfter,
      referenceId,
    });

    res.status(200).json({ success: true, data: { transaction: serializeTransaction(tx) } });
  } catch (err) {
    if (err instanceof InvalidAmountError) {
      res.status(400).json({ success: false, message: "amount must be a positive number not exceeding 1000000." });
      return;
    }
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /wallet/withdraw/request
// ---------------------------------------------------------------------------

/**
 * Create a withdrawal request: debit `amount` points from `playerId` and
 * record a Withdrawal transaction.  No payment gateway involved.
 *
 * Returns 422 when the player's balance is insufficient.
 *
 * Body: { playerId, amount, referenceId? }
 */
export function requestWithdraw(req: Request, res: Response): void {
  const playerId = parsePlayerId(req.body["playerId"]);
  if (!playerId) {
    res.status(400).json({ success: false, message: "playerId is required." });
    return;
  }

  if (req.body["amount"] === undefined || req.body["amount"] === null || req.body["amount"] === "") {
    res.status(400).json({ success: false, message: "amount is required." });
    return;
  }

  const amount = parseAmount(req.body["amount"]);
  if (amount === null) {
    res.status(400).json({
      success: false,
      message: `amount must be a positive number not exceeding ${MAX_AMOUNT}.`,
    });
    return;
  }

  const referenceId = parseReferenceId(req.body["referenceId"]);

  try {
    const balanceBefore = getBalance(playerId);
    debitPlayer(playerId, amount);
    const balanceAfter = getBalance(playerId);

    const tx = createTransaction({
      playerId,
      type: "Withdrawal",
      amount,
      balanceBefore,
      balanceAfter,
      referenceId,
    });

    res.status(200).json({ success: true, data: { transaction: serializeTransaction(tx) } });
  } catch (err) {
    if (err instanceof InsufficientBalanceError) {
      res.status(422).json({ success: false, message: "Insufficient balance." });
      return;
    }
    if (err instanceof InvalidAmountError) {
      res.status(400).json({ success: false, message: "amount must be a positive number not exceeding 1000000." });
      return;
    }
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
