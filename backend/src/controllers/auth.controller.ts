/**
 * Auth controller — handles registration (Phase 2.2) and login (Phase 2.3).
 * Validation is kept inline here; a shared middleware will be extracted
 * once more endpoints exist.
 */

import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import {
  findByEmail,
  findByMobile,
  findByEmailOrMobile,
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

    log.info({ player_id: user.player_id }, "Player logged in.");

    // ── 7. Respond — never include password_hash ──────────────────────────
    res.status(200).json({
      success: true,
      data: {
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
    });
  } catch (err) {
    log.error({ err }, "Login: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
