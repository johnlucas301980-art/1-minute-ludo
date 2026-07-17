/**
 * OTP utilities for password reset.
 *
 * Generates cryptographically secure 6-digit numeric codes and stores/verifies
 * them as SHA-256 hashes. Plaintext OTPs are never persisted.
 *
 * SHA-256 is chosen over bcrypt deliberately: a 6-digit OTP has low entropy by
 * nature, so hashing strength is not the primary defence. The real protections
 * are rate limiting (max 3 requests/hour), a short TTL (15 min), and a 5-attempt
 * lockout. SHA-256 is fast enough for verification and avoids bcrypt latency on
 * a time-sensitive flow.
 */

import { randomInt, createHash, timingSafeEqual } from "node:crypto";

const OTP_MIN = 100_000; // inclusive
const OTP_MAX = 999_999; // inclusive → randomInt(min, max+1)

/** Generate a cryptographically secure 6-digit numeric OTP string. */
export function generateOtp(): string {
  return String(randomInt(OTP_MIN, OTP_MAX + 1));
}

/** Return the SHA-256 hex digest of a plaintext OTP. */
export function hashOtp(otp: string): string {
  return createHash("sha256").update(otp).digest("hex");
}

/**
 * Constant-time comparison of a plaintext OTP against its stored SHA-256 hash.
 * Both hex strings are always 64 characters, so the length check always passes,
 * but it is kept for safety.
 */
export function verifyOtp(otp: string, storedHash: string): boolean {
  const incoming = Buffer.from(hashOtp(otp));
  const stored = Buffer.from(storedHash);
  if (incoming.length !== stored.length) return false;
  return timingSafeEqual(incoming, stored);
}
