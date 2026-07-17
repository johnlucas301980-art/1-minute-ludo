/**
 * JWT utility functions for 1 Minute Ludo.
 *
 * Two token types:
 *  - Access token  (15 min)  — authorises API requests
 *  - Refresh token (30 days) — issues new access tokens
 *
 * Each type uses a separate secret and carries a `type` field so a refresh
 * token cannot be used where an access token is expected, and vice-versa.
 */

import jwt from "jsonwebtoken";
import { env } from "../config/env";

// ---------------------------------------------------------------------------
// Payload shapes
// ---------------------------------------------------------------------------

export interface AccessTokenPayload {
  sub: string;       // user.id (UUID)
  player_id: string;
  type: "access";
}

export interface RefreshTokenPayload {
  sub: string;       // user.id (UUID)
  jti: string;       // unique token ID (UUID v4) — stored in DB for revocation
  type: "refresh";
}

// ---------------------------------------------------------------------------
// Sign
// ---------------------------------------------------------------------------

export function signAccessToken(userId: string, playerId: string): string {
  const payload: Omit<AccessTokenPayload, "iat" | "exp"> = {
    sub: userId,
    player_id: playerId,
    type: "access",
  };
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, { expiresIn: "15m" });
}

export function signRefreshToken(userId: string, jti: string): string {
  const payload: Omit<RefreshTokenPayload, "iat" | "exp"> = {
    sub: userId,
    jti,
    type: "refresh",
  };
  return jwt.sign(payload, env.JWT_REFRESH_SECRET, { expiresIn: "30d" });
}

// ---------------------------------------------------------------------------
// Verify — throws on invalid/expired/wrong-type token
// ---------------------------------------------------------------------------

export function verifyAccessToken(token: string): AccessTokenPayload {
  const payload = jwt.verify(token, env.JWT_ACCESS_SECRET) as AccessTokenPayload;
  if (payload.type !== "access") {
    throw new jwt.JsonWebTokenError("Invalid token type.");
  }
  return payload;
}

export function verifyRefreshToken(token: string): RefreshTokenPayload {
  const payload = jwt.verify(token, env.JWT_REFRESH_SECRET) as RefreshTokenPayload;
  if (payload.type !== "refresh") {
    throw new jwt.JsonWebTokenError("Invalid token type.");
  }
  return payload;
}

// ---------------------------------------------------------------------------
// Password reset token — signed with JWT_PASSWORD_RESET_SECRET (separate secret)
// ---------------------------------------------------------------------------

export interface PasswordResetTokenPayload {
  sub: string;      // user.id (UUID)
  otp_id: string;   // password_reset_otps.id — ties the token to the exact OTP row
  type: "password_reset";
}

/**
 * Sign a 15-minute password reset token.
 * Uses JWT_PASSWORD_RESET_SECRET — never the access or refresh secret.
 */
export function signPasswordResetToken(userId: string, otpId: string): string {
  const payload: Omit<PasswordResetTokenPayload, "iat" | "exp"> = {
    sub: userId,
    otp_id: otpId,
    type: "password_reset",
  };
  return jwt.sign(payload, env.JWT_PASSWORD_RESET_SECRET, { expiresIn: "15m" });
}

/**
 * Verify a password reset token.
 * Throws JsonWebTokenError if the token was signed with any other secret or
 * carries a different `type` — preventing token type confusion attacks.
 */
export function verifyPasswordResetToken(token: string): PasswordResetTokenPayload {
  const payload = jwt.verify(
    token,
    env.JWT_PASSWORD_RESET_SECRET,
  ) as PasswordResetTokenPayload;
  if (payload.type !== "password_reset") {
    throw new jwt.JsonWebTokenError("Invalid token type.");
  }
  return payload;
}
