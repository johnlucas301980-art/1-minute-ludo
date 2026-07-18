/**
 * Wallet controller — Phase 4.1 (Wallet Backend Foundation).
 *
 * GET /api/wallet         — return the authenticated player's wallet balance.
 * GET /api/wallet/history — return a paginated transaction history.
 */

import type { Request, Response } from "express";
import { findOrCreateWallet, getTransactions } from "../services/wallet.service";

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
