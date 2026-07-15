/**
 * Authentication middleware for 1 Minute Ludo.
 *
 * Reads the Bearer token from the Authorization header, verifies it as an
 * access token, and attaches the decoded payload to `req.user`.
 *
 * Usage:
 *   router.get("/protected", authenticate, handler);
 */

import type { Request, Response, NextFunction } from "express";
import { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";
import { verifyAccessToken } from "../lib/jwt";

export function authenticate(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const authHeader = req.headers["authorization"];

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ success: false, message: "Unauthorised." });
    return;
  }

  const token = authHeader.slice(7); // strip "Bearer "

  try {
    const payload = verifyAccessToken(token);
    req.user = { id: payload.sub, player_id: payload.player_id };
    next();
  } catch (err) {
    if (err instanceof TokenExpiredError) {
      res.status(401).json({ success: false, message: "Access token expired." });
      return;
    }
    if (err instanceof JsonWebTokenError) {
      res.status(401).json({ success: false, message: "Invalid access token." });
      return;
    }
    // Unexpected error — treat as unauthorised
    res.status(401).json({ success: false, message: "Unauthorised." });
  }
}
