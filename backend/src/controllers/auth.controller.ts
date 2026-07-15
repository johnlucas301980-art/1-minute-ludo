/**
 * Auth controller — handles registration (Phase 2.2) and login (Phase 2.3).
 * Validation is kept inline here; a shared middleware will be extracted
 * once more endpoints exist.
 */

import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import { randomUUID } from "node:crypto";
import jwt, { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../lib/jwt";
import {
  findByEmail,
  findByMobile,
  findByEmailOrMobile,
  findById,
  findRefreshToken,
  saveRefreshToken,
  deleteRefreshToken,
  deleteRefreshTokensByUser,
  updateLastLogin,
  createUser,
} from "../services/user.service";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MOBILE_RE = /^\+[1-9]\d{6,14}$/; // E.164: + then 7–15 digits

interface ValidationError {
  field: string;
  message: string;
}

// ---------------------------------------------------------------------------
// POST /api/auth/register
// ---------------------------------------------------------------------------

export async function register(req: Request, res: Response): Promise<void> {
  const log = req.log;

  // ── 1. Extract & coerce fields ────────────────────────────────────────────
  const full_name: unknown = req.body?.full_name;
  const email: unknown = req.body?.email;
  const mobile: unknown = req.body?.mobile;
  const password: unknown = req.body?.password;

  const fullNameStr = typeof full_name === "string" ? full_name.trim() : null;
  const emailStr =
    typeof email === "string" && email.trim() !== ""
      ? email.trim().toLowerCase()
      : null;
  const mobileStr =
    typeof mobile === "string" && mobile.trim() !== "" ? mobile.trim() : null;
  const passwordStr = typeof password === "string" ? password : null;

  // ── 2. Validate ───────────────────────────────────────────────────────────
  const errors: ValidationError[] = [];

  if (!fullNameStr) {
    errors.push({ field: "full_name", message: "Full name is required." });
  } else if (fullNameStr.length < 2) {
    errors.push({
      field: "full_name",
      message: "Full name must be at least 2 characters.",
    });
  } else if (fullNameStr.length > 120) {
    errors.push({
      field: "full_name",
      message: "Full name must not exceed 120 characters.",
    });
  }

  if (!emailStr && !mobileStr) {
    errors.push({
      field: "email",
      message: "At least one of email or mobile is required.",
    });
  }

  if (emailStr && !EMAIL_RE.test(emailStr)) {
    errors.push({ field: "email", message: "Invalid email format." });
  }

  if (mobileStr && !MOBILE_RE.test(mobileStr)) {
    errors.push({
      field: "mobile",
      message: "Invalid mobile number. Use E.164 format (e.g. +2348012345678).",
    });
  }

  if (!passwordStr) {
    errors.push({ field: "password", message: "Password is required." });
  } else if (passwordStr.length < 8) {
    errors.push({
      field: "password",
      message: "Password must be at least 8 characters.",
    });
  } else if (!/[a-zA-Z]/.test(passwordStr)) {
    errors.push({
      field: "password",
      message: "Password must contain at least one letter.",
    });
  } else if (!/[0-9]/.test(passwordStr)) {
    errors.push({
      field: "password",
      message: "Password must contain at least one digit.",
    });
  }

  if (errors.length > 0) {
    res.status(400).json({ success: false, message: "Validation failed.", errors });
    return;
  }

  // ── 3. Duplicate checks ───────────────────────────────────────────────────
  try {
    if (emailStr) {
      const existing = await findByEmail(emailStr);
      if (existing) {
        res
          .status(409)
          .json({ success: false, message: "Email is already registered." });
        return;
      }
    }

    if (mobileStr) {
      const existing = await findByMobile(mobileStr);
      if (existing) {
        res
          .status(409)
          .json({
            success: false,
            message: "Mobile number is already registered.",
          });
        return;
      }
    }

    // ── 4. Hash password ──────────────────────────────────────────────────
    const password_hash = await bcrypt.hash(passwordStr!, 12);

    // ── 5. Persist ────────────────────────────────────────────────────────
    const user = await createUser({
      full_name: fullNameStr!,
      email: emailStr,
      mobile: mobileStr,
      password_hash,
    });

    log.info({ player_id: user.player_id }, "New player registered.");

    res.status(201).json({
      success: true,
      data: {
        player_id: user.player_id,
        full_name: user.full_name,
        message: "Registration successful.",
      },
    });
  } catch (err) {
    log.error({ err }, "Register: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /api/auth/login
// ---------------------------------------------------------------------------

export async function login(req: Request, res: Response): Promise<void> {
  const log = req.log;

  // ── 1. Extract & coerce ───────────────────────────────────────────────────
  const identifier: unknown = req.body?.identifier;
  const password: unknown = req.body?.password;

  const identifierStr =
    typeof identifier === "string" && identifier.trim() !== ""
      ? identifier.trim()
      : null;
  const passwordStr =
    typeof password === "string" && password !== "" ? password : null;

  // ── 2. Validate ───────────────────────────────────────────────────────────
  const errors: ValidationError[] = [];

  if (!identifierStr) {
    errors.push({
      field: "identifier",
      message: "Email or mobile number is required.",
    });
  }

  if (!passwordStr) {
    errors.push({ field: "password", message: "Password is required." });
  }

  if (errors.length > 0) {
    res.status(400).json({ success: false, message: "Validation failed.", errors });
    return;
  }

  try {
    // ── 3. Look up account ────────────────────────────────────────────────
    const user = await findByEmailOrMobile(identifierStr!);

    if (!user) {
      res.status(401).json({ success: false, message: "Invalid credentials." });
      return;
    }

    // ── 4. Verify password ────────────────────────────────────────────────
    const passwordMatch = await bcrypt.compare(passwordStr!, user.password_hash);

    if (!passwordMatch) {
      res.status(401).json({ success: false, message: "Invalid credentials." });
      return;
    }

    // ── 5. Check account status ───────────────────────────────────────────
    if (user.status === "suspended") {
      res
        .status(403)
        .json({ success: false, message: "Your account has been suspended." });
      return;
    }

    if (user.status === "banned") {
      res
        .status(403)
        .json({ success: false, message: "Your account has been banned." });
      return;
    }

    // ── 6. Stamp last_login_at (hard error on failure) ────────────────────
    await updateLastLogin(user.id);

    // ── 7. Issue tokens ───────────────────────────────────────────────────
    const jti = randomUUID();
    const accessToken = signAccessToken(user.id, user.player_id);
    const refreshToken = signRefreshToken(user.id, jti);

    // Refresh token expires in 30 days — persist jti for revocation tracking
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await saveRefreshToken(user.id, jti, expiresAt);

    log.info({ player_id: user.player_id }, "Player logged in.");

    // ── 8. Respond — never include password_hash ──────────────────────────
    res.status(200).json({
      success: true,
      data: {
        access_token: accessToken,
        refresh_token: refreshToken,
        profile: {
          id: user.id,
          player_id: user.player_id,
          full_name: user.full_name,
          email: user.email,
          mobile: user.mobile,
          country: user.country,
          avatar: user.avatar,
          status: user.status,
          created_at: user.created_at,
        },
      },
    });
  } catch (err) {
    log.error({ err }, "Login: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /api/auth/refresh
// ---------------------------------------------------------------------------

export async function refresh(req: Request, res: Response): Promise<void> {
  const log = req.log;

  const rawToken: unknown = req.body?.refresh_token;
  const tokenStr = typeof rawToken === "string" && rawToken.trim() !== "" ? rawToken.trim() : null;

  if (!tokenStr) {
    res.status(400).json({
      success: false,
      message: "Validation failed.",
      errors: [{ field: "refresh_token", message: "Refresh token is required." }],
    });
    return;
  }

  try {
    // ── 1. Verify signature + expiry ──────────────────────────────────────
    const payload = verifyRefreshToken(tokenStr);

    // ── 2. Check jti exists in DB (not revoked) ───────────────────────────
    const stored = await findRefreshToken(payload.jti);
    if (!stored) {
      res.status(401).json({ success: false, message: "Invalid or revoked refresh token." });
      return;
    }

    // ── 3. Load user and check status ────────────────────────────────────
    const userById = await findById(payload.sub);
    if (!userById) {
      res.status(401).json({ success: false, message: "Invalid or revoked refresh token." });
      return;
    }
    if (userById.status === "suspended") {
      res.status(403).json({ success: false, message: "Your account has been suspended." });
      return;
    }
    if (userById.status === "banned") {
      res.status(403).json({ success: false, message: "Your account has been banned." });
      return;
    }

    // ── 4. Issue new access token ─────────────────────────────────────────
    const newAccessToken = signAccessToken(userById.id, userById.player_id);

    log.info({ player_id: userById.player_id }, "Access token refreshed.");

    res.status(200).json({
      success: true,
      data: { access_token: newAccessToken },
    });
  } catch (err) {
    if (err instanceof TokenExpiredError) {
      res.status(401).json({ success: false, message: "Refresh token has expired." });
      return;
    }
    if (err instanceof JsonWebTokenError) {
      res.status(401).json({ success: false, message: "Invalid refresh token." });
      return;
    }
    log.error({ err }, "Refresh: unexpected error.");
    res.status(500).json({ success: false, message: "An unexpected error occurred. Please try again." });
  }
}

// ---------------------------------------------------------------------------
// POST /api/auth/logout   (requires authenticate middleware)
// ---------------------------------------------------------------------------

export async function logout(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  const allDevices = req.body?.all_devices === true;
  const rawToken: unknown = req.body?.refresh_token;
  const tokenStr = typeof rawToken === "string" && rawToken.trim() !== "" ? rawToken.trim() : null;

  try {
    if (allDevices) {
      // Revoke every refresh token for this user
      await deleteRefreshTokensByUser(userId);
      log.info({ userId }, "Player logged out from all devices.");
    } else {
      // Revoke only the specific refresh token supplied by the client
      if (!tokenStr) {
        res.status(400).json({
          success: false,
          message: "Validation failed.",
          errors: [{ field: "refresh_token", message: "refresh_token is required when all_devices is not true." }],
        });
        return;
      }

      let jti: string;
      try {
        const payload = verifyRefreshToken(tokenStr);
        jti = payload.jti;
      } catch {
        // Expired tokens are still valid for logout — extract jti without expiry check
        const decoded = jwt.decode(tokenStr) as { jti?: string; type?: string } | null;
        if (!decoded?.jti || decoded.type !== "refresh") {
          res.status(400).json({ success: false, message: "Invalid refresh token." });
          return;
        }
        jti = decoded.jti;
      }

      await deleteRefreshToken(jti, userId);
      log.info({ userId, jti }, "Player logged out from current device.");
    }

    res.status(200).json({ success: true, message: "Logged out successfully." });
  } catch (err) {
    log.error({ err }, "Logout: unexpected error.");
    res.status(500).json({ success: false, message: "An unexpected error occurred. Please try again." });
  }
}
