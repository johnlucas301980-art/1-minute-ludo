/**
 * Country controller — public geo-detection and country listing.
 *
 * GET /api/geo/detect   — detects the caller's country from IP and returns
 *                         the full country list so clients can build a picker.
 */

import type { Request, Response } from "express";
import { listCountries, getCountry } from "../services/country.service.js";

// ---------------------------------------------------------------------------
// IP geolocation helper (uses free ip-api.com — no key required)
// ---------------------------------------------------------------------------

interface IpApiResponse {
  status: "success" | "fail";
  country: string;
  countryCode: string;
}

async function detectCountryFromIp(
  ip: string,
): Promise<{ iso2: string; name: string } | null> {
  // Skip private / loopback addresses — can't geo-locate them.
  if (
    ip === "127.0.0.1" ||
    ip === "::1" ||
    ip === "::ffff:127.0.0.1" ||
    ip.startsWith("10.") ||
    ip.startsWith("192.168.") ||
    ip.startsWith("172.16.") ||
    ip.startsWith("172.17.") ||
    ip.startsWith("172.18.") ||
    ip.startsWith("172.19.") ||
    ip.startsWith("172.2") ||
    ip.startsWith("172.30.") ||
    ip.startsWith("172.31.")
  ) {
    return null;
  }

  try {
    const resp = await fetch(`http://ip-api.com/json/${ip}?fields=status,country,countryCode`, {
      signal: AbortSignal.timeout(3_500),
    });
    if (!resp.ok) return null;

    const data = (await resp.json()) as IpApiResponse;
    if (data.status !== "success") return null;
    return { iso2: data.countryCode, name: data.country };
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// GET /api/geo/detect
// ---------------------------------------------------------------------------

export async function detectCountryHandler(req: Request, res: Response): Promise<void> {
  // Honour X-Forwarded-For set by reverse proxies (Replit, nginx, etc.).
  const forwarded = req.headers["x-forwarded-for"];
  const rawIp =
    typeof forwarded === "string"
      ? forwarded.split(",")[0].trim()
      : (req.socket.remoteAddress ?? "127.0.0.1");

  // Run IP detection and country-list fetch concurrently.
  const [detected, countries] = await Promise.all([
    detectCountryFromIp(rawIp),
    listCountries(),
  ]);

  // Look up the full access record for the detected country.
  let detectedRow = null;
  if (detected) {
    // Prefer DB record; fall back to the raw detection result.
    const dbRow = await getCountry(detected.iso2);
    if (dbRow) {
      detectedRow = {
        iso2: dbRow.iso2,
        name: dbRow.name,
        dial_code: dbRow.dial_code,
        phone_example: dbRow.phone_example,
        is_allowed: dbRow.is_allowed,
        allow_registration: dbRow.allow_registration,
        allow_login: dbRow.allow_login,
      };
    } else {
      // Country not seeded yet — include basic info, treat as allowed.
      detectedRow = {
        iso2: detected.iso2,
        name: detected.name,
        dial_code: "",
        phone_example: "",
        is_allowed: true,
        allow_registration: true,
        allow_login: true,
      };
    }
  }

  res.status(200).json({
    success: true,
    data: {
      detected: detectedRow,
      countries: countries.map((c) => ({
        iso2: c.iso2,
        name: c.name,
        dial_code: c.dial_code,
        phone_example: c.phone_example,
        is_allowed: c.is_allowed,
        allow_registration: c.allow_registration,
        allow_login: c.allow_login,
      })),
    },
  });
}
