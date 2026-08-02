/**
 * Auth controller — registration, login, token refresh, and logout.
 *
 * Phase additions:
 * - Country access control (Phase 1): blocks register/login for restricted countries.
 * - Phone ↔ country validation (Phase 2): ensures the mobile number's dial code
 *   matches the selected country.
 * - Improved password rules (Phase 3 & 4): upper + lower + digit required.
 * - Field-level error array returned on every 400 (Phase 3).
 */

import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import { randomUUID } from "node:crypto";
import jwt, { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";
import { OAuth2Client } from "google-auth-library";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../lib/jwt.js";
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
  findByReferralCode,
  findByGoogleId,
  linkGoogleId,
  createGoogleUser,
  saveLoginHistory,
  getLoginHistory,
} from "../services/user.service.js";
import { checkCountryAccess, getCountry } from "../services/country.service.js";
import { getSetting } from "../services/admin.service.js";
import { grantReward } from "../services/wallet.service.js";

const googleClient = new OAuth2Client();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const EMAIL_RE   = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MOBILE_RE  = /^\+[1-9]\d{6,14}$/; // E.164: + then 7–15 digits

interface ValidationError {
  field: string;
  message: string;
}

// ---------------------------------------------------------------------------
// POST /api/auth/register
// ---------------------------------------------------------------------------

export async function register(req: Request, res: Response): Promise<void> {
  const log = req.log;

  // ── 1. Extract & coerce fields ─────────────────────────────────────────────
  const full_name:    unknown = req.body?.full_name;
  const email:        unknown = req.body?.email;
  const mobile:       unknown = req.body?.mobile;
  const password:     unknown = req.body?.password;
  const country_iso2: unknown = req.body?.country_iso2;
  const referral_code: unknown = req.body?.referral_code;

  const fullNameStr    = typeof full_name    === "string" ? full_name.trim()                            : null;
  const emailStr       = typeof email        === "string" && email.trim() !== "" ? email.trim().toLowerCase() : null;
  const mobileStr      = typeof mobile       === "string" && mobile.trim() !== "" ? mobile.trim()        : null;
  const passwordStr    = typeof password     === "string" ? password                                     : null;
  const countryIso2Str = typeof country_iso2 === "string" && country_iso2.trim() !== ""
    ? country_iso2.trim().toUpperCase()
    : null;
  const referralCodeStr = typeof referral_code === "string" && referral_code.trim() !== ""
    ? referral_code.trim().toUpperCase()
    : null;

  // ── 2. Country access check (before field validation for a fast rejection) ─
  if (countryIso2Str) {
    const access = await checkCountryAccess(countryIso2Str, "registration");
    if (!access.allowed) {
      res.status(403).json({
        success: false,
        message: access.message,
        code: "COUNTRY_BLOCKED",
      });
      return;
    }
  }

  // ── 3. Field-level validation ──────────────────────────────────────────────
  const errors: ValidationError[] = [];

  if (!fullNameStr) {
    errors.push({ field: "full_name", message: "Full name is required." });
  } else if (fullNameStr.length < 2) {
    errors.push({ field: "full_name", message: "Full name must be at least 2 characters." });
  } else if (fullNameStr.length > 120) {
    errors.push({ field: "full_name", message: "Full name must not exceed 120 characters." });
  }

  if (!emailStr && !mobileStr) {
    errors.push({
      field: "email",
      message: "At least one of email or mobile number is required.",
    });
  }

  if (emailStr && !EMAIL_RE.test(emailStr)) {
    errors.push({ field: "email", message: "Email address is invalid." });
  }

  if (mobileStr) {
    if (!MOBILE_RE.test(mobileStr)) {
      errors.push({
        field: "mobile",
        message: "Mobile number must include the correct international country code (e.g. +919876543210).",
      });
    } else if (countryIso2Str) {
      // Phone ↔ country dial-code validation (Phase 2).
      const countryRow = await getCountry(countryIso2Str);
      if (countryRow && countryRow.dial_code && !mobileStr.startsWith(countryRow.dial_code)) {
        errors.push({
          field: "mobile",
          message: "The phone number does not match the selected country.",
        });
      }
    }
  }

  if (!passwordStr) {
    errors.push({ field: "password", message: "Password is required." });
  } else if (passwordStr.length < 8) {
    errors.push({ field: "password", message: "Password must be at least 8 characters." });
  } else if (!/[A-Z]/.test(passwordStr)) {
    errors.push({ field: "password", message: "Password must contain at least one uppercase letter." });
  } else if (!/[a-z]/.test(passwordStr)) {
    errors.push({ field: "password", message: "Password must contain at least one lowercase letter." });
  } else if (!/[0-9]/.test(passwordStr)) {
    errors.push({ field: "password", message: "Password must contain at least one number." });
  }

  if (errors.length > 0) {
    res.status(400).json({ success: false, message: errors[0]!.message, errors });
    return;
  }

  // ── 4. Duplicate checks ────────────────────────────────────────────────────
  try {
    if (emailStr) {
      const existing = await findByEmail(emailStr);
      if (existing) {
        res.status(409).json({
          success: false,
          message: "Email address is already registered.",
          errors: [{ field: "email", message: "Email address is already registered." }],
        });
        return;
      }
    }

    if (mobileStr) {
      const existing = await findByMobile(mobileStr);
      if (existing) {
        res.status(409).json({
          success: false,
          message: "Mobile number is already registered.",
          errors: [{ field: "mobile", message: "Mobile number is already registered." }],
        });
        return;
      }
    }

    // ── 5. Referral code lookup (optional) ────────────────────────────────────
    let referrerId: string | null = null;
    if (referralCodeStr) {
      const referrer = await findByReferralCode(referralCodeStr);
      if (!referrer) {
        res.status(400).json({
          success: false,
          message: "Referral code is invalid.",
          errors: [{ field: "referral_code", message: "Referral code is invalid." }],
        });
        return;
      }
      referrerId = referrer.id;
    }

    // ── 6. Hash & persist ─────────────────────────────────────────────────────
    const password_hash = await bcrypt.hash(passwordStr!, 12);

    const user = await createUser({
      full_name:   fullNameStr!,
      email:       emailStr,
      mobile:      mobileStr,
      password_hash,
      country:     countryIso2Str,
      referred_by: referrerId,
    });

    log.info({ player_id: user.player_id }, "New player registered.");

    // ── 7. Welcome Bonus (if enabled) ─────────────────────────────────────────
    try {
      const enabledSetting = await getSetting("welcome_bonus_enabled");
      if (enabledSetting?.value === "true") {
        const amountSetting = await getSetting("welcome_bonus_amount");
        const bonusAmount = amountSetting ? parseFloat(amountSetting.value) : 0;
        if (bonusAmount > 0) {
          await grantReward(user.id, bonusAmount, "Welcome Bonus");
          log.info({ player_id: user.player_id, amount: bonusAmount }, "Welcome Bonus credited.");
        }
      }
    } catch (bonusErr) {
      // Non-fatal: log and continue — registration succeeds regardless.
      log.warn({ err: bonusErr, player_id: user.player_id }, "Welcome Bonus grant failed; user registered without bonus.");
    }

    res.status(201).json({
      success: true,
      data: {
        id:         user.id,
        player_id:  user.player_id,
        full_name:  user.full_name,
        email:      user.email ?? null,
        mobile:     user.mobile ?? null,
        status:     user.status,
        created_at: user.created_at instanceof Date
          ? user.created_at.toISOString()
          : user.created_at,
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

  // ── 1. Extract & coerce ────────────────────────────────────────────────────
  const identifier:   unknown = req.body?.identifier;
  const password:     unknown = req.body?.password;
  const country_iso2: unknown = req.body?.country_iso2;

  const identifierStr = typeof identifier === "string" && identifier.trim() !== ""
    ? identifier.trim()
    : null;
  const passwordStr = typeof password === "string" && password !== "" ? password : null;
  const countryIso2Str = typeof country_iso2 === "string" && country_iso2.trim() !== ""
    ? country_iso2.trim().toUpperCase()
    : null;

  // ── 2. Country access check ────────────────────────────────────────────────
  if (countryIso2Str) {
    const access = await checkCountryAccess(countryIso2Str, "login");
    if (!access.allowed) {
      res.status(403).json({
        success: false,
        message: access.message,
        code: "COUNTRY_BLOCKED",
      });
      return;
    }
  }

  // ── 3. Validate ────────────────────────────────────────────────────────────
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
    res.status(400).json({ success: false, message: errors[0]!.message, errors });
    return;
  }

  try {
    // ── 4. Look up account ────────────────────────────────────────────────────
    const user = await findByEmailOrMobile(identifierStr!);

    if (!user) {
      res.status(401).json({ success: false, message: "Invalid credentials." });
      return;
    }

    // ── 5. Verify password ────────────────────────────────────────────────────
    const passwordMatch = await bcrypt.compare(passwordStr!, user.password_hash);
    if (!passwordMatch) {
      res.status(401).json({ success: false, message: "Invalid credentials." });
      return;
    }

    // ── 6. Check account status ───────────────────────────────────────────────
    if (user.status === "suspended") {
      res.status(403).json({ success: false, message: "Your account has been suspended." });
      return;
    }
    if (user.status === "banned") {
      res.status(403).json({ success: false, message: "Your account has been banned." });
      return;
    }

    // ── 7. Stamp last_login_at ────────────────────────────────────────────────
    await updateLastLogin(user.id);

    // ── 8. Issue tokens ───────────────────────────────────────────────────────
    const jti = randomUUID();
    const accessToken  = signAccessToken(user.id, user.player_id);
    const refreshToken = signRefreshToken(user.id, jti);

    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await saveRefreshToken(user.id, jti, expiresAt);

    // ── 9. Record login history (non-fatal) ───────────────────────────────────
    const loginMethod = identifierStr && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifierStr)
      ? "email"
      : "mobile";
    try {
      const rawDeviceName: unknown = req.body?.device_name;
      const rawPlatform:   unknown = req.body?.platform;
      await saveLoginHistory({
        user_id:      user.id,
        device_name:  typeof rawDeviceName === "string" && rawDeviceName.trim() !== "" ? rawDeviceName.trim() : null,
        platform:     typeof rawPlatform   === "string" && rawPlatform.trim()   !== "" ? rawPlatform.trim()   : null,
        country:      countryIso2Str,
        login_method: loginMethod,
      });
    } catch (historyErr) {
      log.warn({ err: historyErr }, "Login history record failed; login continues.");
    }

    log.info({ player_id: user.player_id }, "Player logged in.");

    res.status(200).json({
      success: true,
      data: {
        access_token:  accessToken,
        refresh_token: refreshToken,
        profile: {
          id:         user.id,
          player_id:  user.player_id,
          full_name:  user.full_name,
          email:      user.email,
          mobile:     user.mobile,
          country:    user.country,
          avatar:     user.avatar,
          status:     user.status,
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
      message: "Refresh token is required.",
      errors: [{ field: "refresh_token", message: "Refresh token is required." }],
    });
    return;
  }

  try {
    const payload = verifyRefreshToken(tokenStr);

    const stored = await findRefreshToken(payload.jti);
    if (!stored) {
      res.status(401).json({ success: false, message: "Invalid or revoked refresh token." });
      return;
    }

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
// POST /api/auth/google
// ---------------------------------------------------------------------------

export async function googleSignIn(req: Request, res: Response): Promise<void> {
  const log = req.log;

  const rawToken: unknown = req.body?.id_token;
  const idToken = typeof rawToken === "string" && rawToken.trim() !== "" ? rawToken.trim() : null;

  if (!idToken) {
    res.status(400).json({
      success: false,
      message: "id_token is required.",
      errors: [{ field: "id_token", message: "id_token is required." }],
    });
    return;
  }

  const googleClientId = process.env["GOOGLE_CLIENT_ID"];
  if (!googleClientId) {
    log.warn("GOOGLE_CLIENT_ID is not set — Google Sign-In is unavailable.");
    res.status(503).json({
      success: false,
      message: "Google Sign-In is not configured on this server.",
    });
    return;
  }

  // ── 1. Verify Google ID token — auth failures are 401, not 500 ──────────────
  let googleId: string;
  let email: string | null;
  let fullName: string;
  let avatar: string | null;
  let emailVerified: boolean;

  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: googleClientId,
    });

    const payload = ticket.getPayload();
    if (!payload) {
      res.status(401).json({ success: false, message: "Invalid Google token." });
      return;
    }

    googleId      = payload.sub;
    email         = payload.email?.toLowerCase() ?? null;
    fullName      = payload.name ?? payload.email ?? "Player";
    avatar        = payload.picture ?? null;
    emailVerified = payload.email_verified === true;
  } catch {
    res.status(401).json({ success: false, message: "Invalid or expired Google token." });
    return;
  }

  // ── 2. Country access check (optional — mirrors login/register behaviour) ──
  const rawCountry: unknown = req.body?.country_iso2;
  const countryIso2Str = typeof rawCountry === "string" && rawCountry.trim() !== ""
    ? rawCountry.trim().toUpperCase()
    : null;

  if (countryIso2Str) {
    const access = await checkCountryAccess(countryIso2Str, "login");
    if (!access.allowed) {
      res.status(403).json({
        success: false,
        message: access.message,
        code: "COUNTRY_BLOCKED",
      });
      return;
    }
  }

  try {
    // ── 3. Find or create the user ────────────────────────────────────────────
    let user = await findByGoogleId(googleId);

    if (!user && email && emailVerified) {
      // Only link by email when Google has verified ownership of that address.
      const existing = await findByEmail(email);
      if (existing) {
        await linkGoogleId(existing.id, googleId);
        user = await findById(existing.id);
      }
    }

    if (!user) {
      if (!email || !emailVerified) {
        res.status(400).json({
          success: false,
          message: emailVerified === false
            ? "Google account email is not verified. Cannot create an account."
            : "Google account has no email address. Cannot create an account.",
        });
        return;
      }
      // New user — create automatically
      const created = await createGoogleUser({ full_name: fullName, email, google_id: googleId, avatar });
      user = await findById(created.id);
    }

    if (!user) {
      res.status(500).json({ success: false, message: "An unexpected error occurred. Please try again." });
      return;
    }

    // ── 3. Check account status ───────────────────────────────────────────────
    if (user.status === "suspended") {
      res.status(403).json({ success: false, message: "Your account has been suspended." });
      return;
    }
    if (user.status === "banned") {
      res.status(403).json({ success: false, message: "Your account has been banned." });
      return;
    }

    // ── 4. Stamp last_login_at ────────────────────────────────────────────────
    await updateLastLogin(user.id);

    // ── 5. Issue tokens ───────────────────────────────────────────────────────
    const jti = randomUUID();
    const accessToken  = signAccessToken(user.id, user.player_id);
    const refreshToken = signRefreshToken(user.id, jti);

    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await saveRefreshToken(user.id, jti, expiresAt);

    // ── 6. Record login history (non-fatal) ───────────────────────────────────
    try {
      const rawDeviceName: unknown = req.body?.device_name;
      const rawPlatform:   unknown = req.body?.platform;
      await saveLoginHistory({
        user_id:      user.id,
        device_name:  typeof rawDeviceName === "string" && rawDeviceName.trim() !== "" ? rawDeviceName.trim() : null,
        platform:     typeof rawPlatform   === "string" && rawPlatform.trim()   !== "" ? rawPlatform.trim()   : null,
        country:      countryIso2Str,
        login_method: "google",
      });
    } catch (historyErr) {
      log.warn({ err: historyErr }, "Login history record failed; Google login continues.");
    }

    log.info({ player_id: user.player_id }, "Player logged in via Google.");

    res.status(200).json({
      success: true,
      data: {
        access_token:  accessToken,
        refresh_token: refreshToken,
        profile: {
          id:         user.id,
          player_id:  user.player_id,
          full_name:  user.full_name,
          email:      user.email,
          mobile:     user.mobile,
          country:    user.country,
          avatar:     user.avatar,
          status:     user.status,
          created_at: user.created_at,
        },
      },
    });
  } catch (err) {
    log.error({ err }, "Google Sign-In: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// GET /api/auth/login-history  (requires authenticate middleware)
// ---------------------------------------------------------------------------

export async function loginHistory(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  try {
    const rows = await getLoginHistory(userId);
    res.status(200).json({
      success: true,
      data: rows.map((r) => ({
        id:           r.id,
        login_time:   r.login_time instanceof Date ? r.login_time.toISOString() : r.login_time,
        device_name:  r.device_name  ?? null,
        platform:     r.platform     ?? null,
        country:      r.country      ?? null,
        login_method: r.login_method,
      })),
    });
  } catch (err) {
    log.error({ err }, "Login history: unexpected error.");
    res.status(500).json({ success: false, message: "An unexpected error occurred. Please try again." });
  }
}

// ---------------------------------------------------------------------------
// POST /api/auth/logout  (requires authenticate middleware)
// ---------------------------------------------------------------------------

export async function logout(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  const allDevices = req.body?.all_devices === true;
  const rawToken: unknown = req.body?.refresh_token;
  const tokenStr = typeof rawToken === "string" && rawToken.trim() !== "" ? rawToken.trim() : null;

  try {
    if (allDevices) {
      await deleteRefreshTokensByUser(userId);
      log.info({ userId }, "Player logged out from all devices.");
    } else {
      if (!tokenStr) {
        res.status(400).json({
          success: false,
          message: "refresh_token is required when all_devices is not true.",
          errors: [{ field: "refresh_token", message: "refresh_token is required when all_devices is not true." }],
        });
        return;
      }

      let jti: string;
      try {
        const payload = verifyRefreshToken(tokenStr);
        jti = payload.jti;
      } catch {
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
