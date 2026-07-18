/**
 * Profile controller — Phase 3.1 (Player Profile Foundation) +
 *                      Phase 3.3 (Change Password) +
 *                      Phase 3.6 (Avatar Upload).
 *
 * GET /api/profile          — return the authenticated player's profile.
 * PUT /api/profile          — update mutable profile fields (full_name, country, avatar).
 * PUT /api/profile/password — change password (verifies current, hashes new, revokes sessions).
 * PUT /api/profile/avatar   — upload a new avatar image (multipart/form-data, field: avatar).
 */

import path from "node:path";
import fs from "node:fs";
import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import { findProfileById, updateProfileById } from "../services/profile.service";
import { findById, updatePasswordById, deleteRefreshTokensByUser } from "../services/user.service";
import { AVATARS_DIR, MIME_TO_EXT } from "../lib/upload";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const AVATAR_URL_RE = /^https?:\/\/.{1,2000}$/;

/** All possible avatar extensions — used to clean up stale files on replace. */
const ALL_AVATAR_EXTS = Object.values(MIME_TO_EXT);

interface ValidationError {
  field: string;
  message: string;
}

// ---------------------------------------------------------------------------
// GET /api/profile
// ---------------------------------------------------------------------------

export async function getProfile(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  try {
    const profile = await findProfileById(userId);

    if (!profile) {
      res.status(404).json({ success: false, message: "Profile not found." });
      return;
    }

    res.status(200).json({ success: true, data: { profile } });
  } catch (err) {
    log.error({ err }, "GetProfile: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// PUT /api/profile
// ---------------------------------------------------------------------------

export async function updateProfile(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  // ── 1. Extract & coerce fields ────────────────────────────────────────────
  const rawFullName: unknown = req.body?.full_name;
  const rawCountry: unknown = req.body?.country;
  const rawAvatar: unknown = req.body?.avatar;

  // ── 2. Require at least one field ────────────────────────────────────────
  if (rawFullName === undefined && rawCountry === undefined && rawAvatar === undefined) {
    res.status(400).json({
      success: false,
      message: "Validation failed.",
      errors: [
        {
          field: "body",
          message: "At least one field (full_name, country, avatar) is required.",
        },
      ],
    });
    return;
  }

  // ── 3. Validate each supplied field ───────────────────────────────────────
  const errors: ValidationError[] = [];
  let fullName: string | undefined;
  let country: string | null | undefined;
  let avatar: string | null | undefined;

  if (rawFullName !== undefined) {
    if (typeof rawFullName !== "string" || rawFullName.trim() === "") {
      errors.push({ field: "full_name", message: "full_name must be a non-empty string." });
    } else if (rawFullName.trim().length < 2) {
      errors.push({ field: "full_name", message: "Full name must be at least 2 characters." });
    } else if (rawFullName.trim().length > 120) {
      errors.push({ field: "full_name", message: "Full name must not exceed 120 characters." });
    } else {
      fullName = rawFullName.trim();
    }
  }

  if (rawCountry !== undefined) {
    if (rawCountry === null) {
      country = null;
    } else if (typeof rawCountry !== "string" || rawCountry.trim() === "") {
      errors.push({ field: "country", message: "country must be a non-empty string or null." });
    } else if (rawCountry.trim().length > 100) {
      errors.push({ field: "country", message: "Country must not exceed 100 characters." });
    } else {
      country = rawCountry.trim();
    }
  }

  if (rawAvatar !== undefined) {
    if (rawAvatar === null) {
      avatar = null;
    } else if (typeof rawAvatar !== "string" || rawAvatar.trim() === "") {
      errors.push({ field: "avatar", message: "avatar must be a non-empty string URL or null." });
    } else if (!AVATAR_URL_RE.test(rawAvatar.trim())) {
      errors.push({ field: "avatar", message: "avatar must be a valid http or https URL." });
    } else {
      avatar = rawAvatar.trim();
    }
  }

  if (errors.length > 0) {
    res.status(400).json({ success: false, message: "Validation failed.", errors });
    return;
  }

  // ── 4. Persist ────────────────────────────────────────────────────────────
  try {
    const updated = await updateProfileById(userId, { full_name: fullName, country, avatar });

    if (!updated) {
      res.status(404).json({ success: false, message: "Profile not found." });
      return;
    }

    log.info({ userId }, "Player profile updated.");
    res.status(200).json({ success: true, data: { profile: updated } });
  } catch (err) {
    log.error({ err }, "UpdateProfile: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// PUT /api/profile/password
// ---------------------------------------------------------------------------

export async function changePassword(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  // ── 1. Extract fields ─────────────────────────────────────────────────────
  const rawCurrent: unknown = req.body?.current_password;
  const rawNew: unknown = req.body?.new_password;

  // ── 2. Validate fields ────────────────────────────────────────────────────
  const errors: ValidationError[] = [];
  let currentPassword: string | undefined;
  let newPassword: string | undefined;

  if (rawCurrent === undefined || rawCurrent === null || rawCurrent === "") {
    errors.push({ field: "current_password", message: "Current password is required." });
  } else if (typeof rawCurrent !== "string") {
    errors.push({ field: "current_password", message: "current_password must be a string." });
  } else {
    currentPassword = rawCurrent;
  }

  if (rawNew === undefined || rawNew === null || rawNew === "") {
    errors.push({ field: "new_password", message: "New password is required." });
  } else if (typeof rawNew !== "string") {
    errors.push({ field: "new_password", message: "new_password must be a string." });
  } else if (rawNew.length < 8) {
    errors.push({ field: "new_password", message: "New password must be at least 8 characters." });
  } else if (!/[a-zA-Z]/.test(rawNew)) {
    errors.push({ field: "new_password", message: "New password must contain at least one letter." });
  } else if (!/[0-9]/.test(rawNew)) {
    errors.push({ field: "new_password", message: "New password must contain at least one digit." });
  } else {
    newPassword = rawNew;
  }

  // ── 3. New must differ from current (plain string check — no bcrypt cost) ─
  if (currentPassword !== undefined && newPassword !== undefined && currentPassword === newPassword) {
    errors.push({
      field: "new_password",
      message: "New password must be different from the current password.",
    });
    newPassword = undefined;
  }

  if (errors.length > 0) {
    res.status(400).json({ success: false, message: "Validation failed.", errors });
    return;
  }

  // ── 4. Load user row to get current password_hash ────────────────────────
  try {
    const user = await findById(userId);

    if (!user) {
      res.status(404).json({ success: false, message: "Profile not found." });
      return;
    }

    // ── 5. Verify current password ─────────────────────────────────────────
    const passwordMatch = await bcrypt.compare(currentPassword!, user.password_hash ?? "");

    if (!passwordMatch) {
      res.status(401).json({ success: false, message: "Current password is incorrect." });
      return;
    }

    // ── 6. Hash new password (cost factor 12 — consistent with registration) ─
    const newPasswordHash = await bcrypt.hash(newPassword!, 12);

    // ── 7. Persist new password hash ──────────────────────────────────────
    await updatePasswordById(userId, newPasswordHash);

    // ── 8. Revoke all refresh tokens — security: password change invalidates
    //       all active sessions on other devices (same as password reset) ────
    await deleteRefreshTokensByUser(userId);

    log.info({ userId }, "Player password changed; all sessions revoked.");
    res.status(200).json({ success: true, message: "Password changed successfully." });
  } catch (err) {
    log.error({ err }, "ChangePassword: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// PUT /api/profile/avatar
// ---------------------------------------------------------------------------

/**
 * Handles avatar image upload for the authenticated player.
 *
 * The multer middleware (handleAvatarUpload in routes/profile.ts) runs first:
 * it validates the MIME type, enforces the 2 MB size limit, and writes the
 * file to disk as <user-id>.<ext> before this handler is invoked.
 *
 * This handler then:
 *   1. Confirms a file was attached (multer sets req.file when successful).
 *   2. Removes any stale avatar files left from a previous upload with a
 *      different extension (e.g. old .jpg when new file is .png).
 *   3. Constructs the public URL and persists it to the avatar column.
 *   4. Returns { success: true, data: { avatar: "<url>" } }.
 */
export async function uploadAvatar(req: Request, res: Response): Promise<void> {
  const log = req.log;
  const userId = req.user!.id;

  // ── 1. Confirm file was received ─────────────────────────────────────────
  if (!req.file) {
    res.status(400).json({
      success: false,
      message: 'No file uploaded. Attach an image file in the "avatar" form field.',
    });
    return;
  }

  const newExt = path.extname(req.file.filename); // e.g. ".jpg"

  // ── 2. Clean up stale avatar files with other extensions ─────────────────
  //    The new file is already written by multer as <user-id>.<ext>.
  //    If the previous avatar had a different extension the old file lingers,
  //    so we delete every other possible extension for this user.
  for (const ext of ALL_AVATAR_EXTS) {
    if (ext !== newExt) {
      const stale = path.join(AVATARS_DIR, `${userId}${ext}`);
      fs.unlink(stale, () => {
        // Intentionally silent — file simply may not exist.
      });
    }
  }

  // ── 3. Build the public URL ───────────────────────────────────────────────
  //    Use the Host header so the URL works in both dev (localhost:5000) and
  //    production (the Replit / custom domain).
  const avatarUrl = `${req.protocol}://${req.get("host")}/uploads/avatars/${req.file.filename}`;

  // ── 4. Persist the avatar URL to the database ────────────────────────────
  try {
    const updated = await updateProfileById(userId, { avatar: avatarUrl });

    if (!updated) {
      res.status(404).json({ success: false, message: "Profile not found." });
      return;
    }

    log.info({ userId, avatarUrl }, "Player avatar updated.");
    res.status(200).json({ success: true, data: { avatar: avatarUrl } });
  } catch (err) {
    log.error({ err }, "UploadAvatar: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
