/**
 * Wallet controller — Phase 4.1 (Wallet Backend Foundation) +
 *                     Phase 4.4 (Deposit & Withdraw Backend Foundation).
 *
 * GET  /api/wallet          — return the authenticated player's wallet balance.
 * GET  /api/wallet/history  — return a paginated transaction history.
 * POST /api/wallet/deposit  — credit points to the wallet (provider-agnostic).
 * POST /api/wallet/withdraw — debit points from the wallet.
 */

import type { Request, Response } from "express";
import {
  findOrCreateWallet,
  getTransactions,
  depositPoints,
  withdrawPoints,
  InsufficientBalanceError,
} from "../services/wallet.service";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const HISTORY_DEFAULT_LIMIT = 20;
const HISTORY_MAX_LIMIT = 100;
const HISTORY_DEFAULT_OFFSET = 0;

// ---------------------------------------------------------------------------
// GET /api/wallet
// ---------------------------------------------------------------------------

/**
 * Returns the authenticated player's wallet.
 * A wallet is created automatically on first access so every registered
 * player always has one — no explicit creation step is required.
 */
export async function getWallet(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  try {
    const wallet = await findOrCreateWallet(userId);

    res.status(200).json({
      success: true,
      data: {
        wallet: {
          id: wallet.id,
          points: parseFloat(wallet.points),
          total_deposit: parseFloat(wallet.total_deposit),
          total_withdraw: parseFloat(wallet.total_withdraw),
          updated_at: wallet.updated_at,
        },
      },
    });
  } catch (err) {
    log.error({ err }, "GetWallet: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// GET /api/wallet/history
// ---------------------------------------------------------------------------

/**
 * Returns a paginated list of the authenticated player's transactions,
 * ordered newest first.
 *
 * Query parameters:
 *   limit  — number of records to return (1–100, default 20)
 *   offset — number of records to skip   (≥ 0,   default 0)
 *
 * Invalid or out-of-range values are silently clamped to safe defaults.
 */
export async function getWalletHistory(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  // ── Parse and sanitise pagination params ──────────────────────────────────
  const rawLimit = parseInt(String(req.query["limit"] ?? ""), 10);
  const rawOffset = parseInt(String(req.query["offset"] ?? ""), 10);

  const limit = Number.isFinite(rawLimit) && rawLimit >= 1
    ? Math.min(rawLimit, HISTORY_MAX_LIMIT)
    : HISTORY_DEFAULT_LIMIT;

  const offset = Number.isFinite(rawOffset) && rawOffset >= 0
    ? rawOffset
    : HISTORY_DEFAULT_OFFSET;

  try {
    const transactions = await getTransactions(userId, limit, offset);

    res.status(200).json({
      success: true,
      data: {
        transactions: transactions.map((tx) => ({
          id: tx.id,
          type: tx.type,
          amount: parseFloat(tx.amount),
          status: tx.status,
          reference: tx.reference,
          created_at: tx.created_at,
        })),
        pagination: {
          limit,
          offset,
          count: transactions.length,
        },
      },
    });
  } catch (err) {
    log.error({ err }, "GetWalletHistory: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /api/wallet/deposit
// ---------------------------------------------------------------------------

/** Maximum allowed amount per single deposit/withdraw request. */
const MAX_TRANSACTION_AMOUNT = 1_000_000;

/** Maximum length of an optional external reference string. */
const MAX_REFERENCE_LENGTH = 255;

/**
 * Credits points to the authenticated player's wallet.
 *
 * This endpoint is payment-provider agnostic: it records the internal ledger
 * movement only.  The caller (mobile app or a future payment-webhook handler)
 * is responsible for verifying that the real-world payment succeeded before
 * calling this endpoint.
 *
 * Request body:
 *   amount    — positive number of points to credit (required)
 *   reference — optional external reference string (e.g. gateway transaction ID)
 *
 * Response (200):
 *   success: true
 *   data.wallet       — updated wallet snapshot
 *   data.transaction  — the completed deposit transaction record
 */
export async function deposit(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  // ── Input validation ──────────────────────────────────────────────────────
  const rawAmount = req.body["amount"];
  const rawReference = req.body["reference"];

  if (rawAmount === undefined || rawAmount === null || rawAmount === "") {
    res.status(400).json({ success: false, message: "amount is required." });
    return;
  }

  const amount = Number(rawAmount);

  if (!Number.isFinite(amount) || amount <= 0) {
    res.status(400).json({
      success: false,
      message: "amount must be a positive number.",
    });
    return;
  }

  if (amount > MAX_TRANSACTION_AMOUNT) {
    res.status(400).json({
      success: false,
      message: `amount must not exceed ${MAX_TRANSACTION_AMOUNT}.`,
    });
    return;
  }

  // Round to 2 decimal places to match NUMERIC(18,2) storage
  const safeAmount = Math.round(amount * 100) / 100;

  let reference: string | undefined;
  if (rawReference !== undefined && rawReference !== null) {
    reference = String(rawReference).trim();
    if (reference.length > MAX_REFERENCE_LENGTH) {
      res.status(400).json({
        success: false,
        message: `reference must not exceed ${MAX_REFERENCE_LENGTH} characters.`,
      });
      return;
    }
    if (reference.length === 0) reference = undefined;
  }

  try {
    const { wallet, transaction } = await depositPoints(userId, safeAmount, reference);

    res.status(200).json({
      success: true,
      data: {
        wallet: {
          id: wallet.id,
          points: parseFloat(wallet.points),
          total_deposit: parseFloat(wallet.total_deposit),
          total_withdraw: parseFloat(wallet.total_withdraw),
          updated_at: wallet.updated_at,
        },
        transaction: {
          id: transaction.id,
          type: transaction.type,
          amount: parseFloat(transaction.amount),
          status: transaction.status,
          reference: transaction.reference,
          created_at: transaction.created_at,
        },
      },
    });
  } catch (err) {
    log.error({ err }, "Deposit: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /api/wallet/withdraw
// ---------------------------------------------------------------------------

/**
 * Debits points from the authenticated player's wallet.
 *
 * Request body:
 *   amount    — positive number of points to debit (required; must not exceed current balance)
 *   reference — optional external reference string
 *
 * Response (200):
 *   success: true
 *   data.wallet       — updated wallet snapshot
 *   data.transaction  — the completed withdrawal transaction record
 *
 * Response (422):
 *   success: false
 *   message — human-readable insufficient-balance error
 */
export async function withdraw(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  // ── Input validation ──────────────────────────────────────────────────────
  const rawAmount = req.body["amount"];
  const rawReference = req.body["reference"];

  if (rawAmount === undefined || rawAmount === null || rawAmount === "") {
    res.status(400).json({ success: false, message: "amount is required." });
    return;
  }

  const amount = Number(rawAmount);

  if (!Number.isFinite(amount) || amount <= 0) {
    res.status(400).json({
      success: false,
      message: "amount must be a positive number.",
    });
    return;
  }

  if (amount > MAX_TRANSACTION_AMOUNT) {
    res.status(400).json({
      success: false,
      message: `amount must not exceed ${MAX_TRANSACTION_AMOUNT}.`,
    });
    return;
  }

  const safeAmount = Math.round(amount * 100) / 100;

  let reference: string | undefined;
  if (rawReference !== undefined && rawReference !== null) {
    reference = String(rawReference).trim();
    if (reference.length > MAX_REFERENCE_LENGTH) {
      res.status(400).json({
        success: false,
        message: `reference must not exceed ${MAX_REFERENCE_LENGTH} characters.`,
      });
      return;
    }
    if (reference.length === 0) reference = undefined;
  }

  try {
    const { wallet, transaction } = await withdrawPoints(userId, safeAmount, reference);

    res.status(200).json({
      success: true,
      data: {
        wallet: {
          id: wallet.id,
          points: parseFloat(wallet.points),
          total_deposit: parseFloat(wallet.total_deposit),
          total_withdraw: parseFloat(wallet.total_withdraw),
          updated_at: wallet.updated_at,
        },
        transaction: {
          id: transaction.id,
          type: transaction.type,
          amount: parseFloat(transaction.amount),
          status: transaction.status,
          reference: transaction.reference,
          created_at: transaction.created_at,
        },
      },
    });
  } catch (err) {
    if (err instanceof InsufficientBalanceError) {
      res.status(422).json({
        success: false,
        message: "Insufficient balance.",
      });
      return;
    }
    log.error({ err }, "Withdraw: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
