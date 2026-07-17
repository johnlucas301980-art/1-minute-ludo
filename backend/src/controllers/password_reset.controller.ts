/**
 * Password reset controller — handles the three-step reset flow.
 *
 * POST /api/auth/password-reset/request  — generate + email OTP
 * POST /api/auth/password-reset/verify   — verify OTP → issue reset token
 * POST /api/auth/password-reset/confirm  — verify reset token → update password
 */

import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";
import { generateOtp, hashOtp, verifyOtp } from "../lib/otp";
import { sendPasswordResetEmail } from "../lib/email";
import {
  signPasswordResetToken,
  verifyPasswordResetToken,
} from "../lib/jwt";
import { findByEmail, findById } from "../services/user.service";
import {
  countRecentOtpRequests,
  createOtp,
  incrementLatestOtpAttempt,
  findOtpById,
  applyPasswordReset,
  MAX_ATTEMPTS,
  MAX_REQUESTS_PER_HOUR,
} from "../services/password_reset.service";

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const OTP_RE = /^\d{6}$/;
const PASSWORD_HAS_LETTER = /[a-zA-Z]/;
const PASSWORD_HAS_DIGIT = /[0-9]/;

interface ValidationError {
  field: string;
  message: string;
}

function validatePassword(value: string, field: string): ValidationError[] {
  const errs: ValidationError[] = [];
  if (value.length < 8)
    errs.push({ field, message: "Password must be at least 8 characters." });
  else if (!PASSWORD_HAS_LETTER.test(value))
    errs.push({ field, message: "Password must contain at least one letter." });
  else if (!PASSWORD_HAS_DIGIT.test(value))
    errs.push({ field, message: "Password must contain at least one digit." });
  return errs;
}

// ---------------------------------------------------------------------------
// POST /api/auth/password-reset/request
// ---------------------------------------------------------------------------

export async function requestPasswordReset(req: Request, res: Response): Promise<void> {
  const log = req.log;

  // ── 1. Validate email ────────────────────────────────────────────────────
  const rawEmail: unknown = req.body?.email;
  const emailStr =
    typeof rawEmail === "string" && rawEmail.trim() !== ""
      ? rawEmail.trim().toLowerCase()
      : null;

  if (!emailStr || !EMAIL_RE.test(emailStr)) {
    res.status(400).json({
      success: false,
      message: "Validation failed.",
      errors: [{ field: "email", message: "A valid email address is required." }],
    });
    return;
  }

  // Always respond with the same message to prevent account enumeration.
  const SAFE_RESPONSE = {
    success: true,
    message: "If that email is registered, an OTP has been sent.",
  };

  try {
    // ── 2. Look up user — silently succeed if not found ──────────────────
    const user = await findByEmail(emailStr);
    if (!user) {
      log.info({ email: emailStr }, "Password reset requested for unknown email.");
      res.status(200).json(SAFE_RESPONSE);
      return;
    }

    // ── 3. Rate limit — max 3 requests per rolling hour ──────────────────
    const recentCount = await countRecentOtpRequests(user.id);
    if (recentCount >= MAX_REQUESTS_PER_HOUR) {
      log.warn({ userId: user.id }, "Password reset rate limit exceeded.");
      res.status(429).json({
        success: false,
        message: "Too many password reset requests. Please wait before trying again.",
      });
      return;
    }

    // ── 4. Generate OTP, store hash ───────────────────────────────────────
    const otp = generateOtp();
    const otpHash = hashOtp(otp);
    await createOtp(user.id, otpHash);

    // ── 5. Send email asynchronously (fire and forget) ────────────────────
    sendPasswordResetEmail(emailStr, otp).catch((err) => {
      log.error({ err, email: emailStr }, "Failed to send password reset email.");
    });

    log.info({ userId: user.id }, "Password reset OTP created.");
    res.status(200).json(SAFE_RESPONSE);
  } catch (err) {
    log.error({ err }, "RequestPasswordReset: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /api/auth/password-reset/verify
// ---------------------------------------------------------------------------

export async function verifyPasswordResetOtp(req: Request, res: Response): Promise<void> {
  const log = req.log;

  // ── 1. Extract & validate ────────────────────────────────────────────────
  const rawEmail: unknown = req.body?.email;
  const rawOtp: unknown = req.body?.otp;

  const emailStr =
    typeof rawEmail === "string" && rawEmail.trim() !== ""
      ? rawEmail.trim().toLowerCase()
      : null;
  const otpStr =
    typeof rawOtp === "string" && rawOtp.trim() !== "" ? rawOtp.trim() : null;

  const errors: ValidationError[] = [];
  if (!emailStr || !EMAIL_RE.test(emailStr))
    errors.push({ field: "email", message: "A valid email address is required." });
  if (!otpStr)
    errors.push({ field: "otp", message: "OTP is required." });
  else if (!OTP_RE.test(otpStr))
    errors.push({ field: "otp", message: "OTP must be exactly 6 digits." });

  if (errors.length > 0) {
    res.status(400).json({ success: false, message: "Validation failed.", errors });
    return;
  }

  try {
    // ── 2. Look up user — generic error avoids email enumeration ─────────
    const user = await findByEmail(emailStr!);
    if (!user) {
      res.status(400).json({ success: false, message: "OTP is invalid or has expired." });
      return;
    }

    // ── 3. Atomically increment attempts on the latest valid OTP ─────────
    const otpRow = await incrementLatestOtpAttempt(user.id);
    if (!otpRow) {
      res.status(400).json({ success: false, message: "OTP is invalid or has expired." });
      return;
    }

    // ── 4. Verify the OTP hash ────────────────────────────────────────────
    if (!verifyOtp(otpStr!, otpRow.otp_hash)) {
      // On the final allowed attempt, surface the lockout message.
      if (otpRow.attempts >= MAX_ATTEMPTS) {
        log.warn({ userId: user.id }, "OTP max attempts reached — row will be skipped.");
        res.status(400).json({
          success: false,
          message: "Too many failed attempts. Please request a new OTP.",
        });
        return;
      }
      res.status(400).json({ success: false, message: "OTP is incorrect." });
      return;
    }

    // ── 5. Issue password reset token ─────────────────────────────────────
    // Token carries the OTP row id so the confirm step can validate the exact
    // session rather than any valid OTP for this user.
    const resetToken = signPasswordResetToken(user.id, otpRow.id);
    log.info({ userId: user.id }, "Password reset OTP verified.");

    res.status(200).json({ success: true, data: { reset_token: resetToken } });
  } catch (err) {
    log.error({ err }, "VerifyPasswordResetOtp: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /api/auth/password-reset/confirm
// ---------------------------------------------------------------------------

export async function confirmPasswordReset(req: Request, res: Response): Promise<void> {
  const log = req.log;

  // ── 1. Extract & validate ────────────────────────────────────────────────
  const rawToken: unknown = req.body?.reset_token;
  const rawPassword: unknown = req.body?.new_password;

  const tokenStr =
    typeof rawToken === "string" && rawToken.trim() !== "" ? rawToken.trim() : null;
  const passwordStr = typeof rawPassword === "string" ? rawPassword : null;

  const errors: ValidationError[] = [];
  if (!tokenStr)
    errors.push({ field: "reset_token", message: "Reset token is required." });
  if (!passwordStr)
    errors.push({ field: "new_password", message: "New password is required." });
  else
    errors.push(...validatePassword(passwordStr, "new_password"));

  if (errors.length > 0) {
    res.status(400).json({ success: false, message: "Validation failed.", errors });
    return;
  }

  try {
    // ── 2. Verify the password reset JWT ──────────────────────────────────
    let payload: ReturnType<typeof verifyPasswordResetToken>;
    try {
      payload = verifyPasswordResetToken(tokenStr!);
    } catch (err) {
      if (err instanceof TokenExpiredError) {
        res.status(401).json({ success: false, message: "Reset token has expired." });
        return;
      }
      if (err instanceof JsonWebTokenError) {
        res.status(401).json({ success: false, message: "Invalid reset token." });
        return;
      }
      throw err;
    }

    // ── 3. Load user and check status ────────────────────────────────────
    const user = await findById(payload.sub);
    if (!user) {
      res.status(401).json({ success: false, message: "Invalid reset token." });
      return;
    }
    if (user.status === "suspended") {
      res.status(403).json({ success: false, message: "Your account has been suspended." });
      return;
    }
    if (user.status === "banned") {
      res.status(403).json({ success: false, message: "Your account has been banned." });
      return;
    }

    // ── 4. Verify the OTP row is still valid (unused, not expired) ───────
    // This check ties the reset token to the specific OTP session and prevents
    // replay after confirm, or use of a token after a new OTP was requested.
    const otpRow = await findOtpById(payload.otp_id, user.id);
    if (!otpRow || otpRow.used_at !== null || otpRow.expires_at < new Date()) {
      res.status(400).json({
        success: false,
        message: "Reset session is no longer valid. Please request a new OTP.",
      });
      return;
    }

    // ── 5. Hash new password ──────────────────────────────────────────────
    const newPasswordHash = await bcrypt.hash(passwordStr!, 12);

    // ── 6. Apply atomically: update password, mark OTP used, revoke sessions
    await applyPasswordReset(user.id, payload.otp_id, newPasswordHash);

    log.info({ userId: user.id }, "Password reset completed — all sessions invalidated.");
    res.status(200).json({ success: true, message: "Password updated successfully." });
  } catch (err) {
    log.error({ err }, "ConfirmPasswordReset: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
