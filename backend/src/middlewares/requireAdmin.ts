/**
 * requireAdmin middleware — Phase 10.1.
 *
 * Must be used after the `authenticate` middleware, which sets `req.user`.
 * Looks up the user's role from the database on every request; this
 * intentionally avoids stale JWT grants giving admin access after a demotion.
 */

import type { Request, Response, NextFunction } from "express";
import { pool } from "../db/index.js";

export async function requireAdmin(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ success: false, message: "Unauthorised." });
    return;
  }

  if (!pool) {
    res.status(503).json({ success: false, message: "Database is not available." });
    return;
  }

  try {
    const { rows } = await pool.query<{ role: string }>(
      "SELECT role FROM users WHERE id = $1",
      [req.user.id],
    );

    if (!rows[0] || rows[0].role !== "admin") {
      res.status(403).json({ success: false, message: "Forbidden." });
      return;
    }

    next();
  } catch (err) {
    req.log.error({ err }, "RequireAdmin: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
