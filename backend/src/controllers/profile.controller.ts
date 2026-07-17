/**
 * Profile controller — Phase 3.1 (Player Profile Foundation).
 *
 * GET /api/profile — return the authenticated player's profile.
 * PUT /api/profile — update mutable profile fields (full_name, country, avatar).
 */

import type { Request, Response } from "express";
import { findProfileById, updateProfileById } from "../services/profile.service";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const AVATAR_URL_RE = /^https?:\/\/.{1,2000}$/;

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
