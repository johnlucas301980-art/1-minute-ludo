import { describe, expect, it } from "vitest";
import { generateOtp, hashOtp, verifyOtp } from "./otp.js";

describe("OTP utilities", () => {
  it("generates a six-digit numeric OTP", () => {
    const otp = generateOtp();

    expect(otp).toMatch(/^\d{6}$/);
    expect(Number(otp)).toBeGreaterThanOrEqual(100_000);
    expect(Number(otp)).toBeLessThanOrEqual(999_999);
  });

  it("hashes the same OTP deterministically", () => {
    const otp = "123456";

    expect(hashOtp(otp)).toBe(hashOtp(otp));
    expect(hashOtp(otp)).toMatch(/^[a-f0-9]{64}$/);
  });

  it("verifies a matching OTP hash", () => {
    const otp = "482901";

    expect(verifyOtp(otp, hashOtp(otp))).toBe(true);
  });

  it("rejects an incorrect OTP", () => {
    expect(verifyOtp("482900", hashOtp("482901"))).toBe(false);
  });

  it("rejects a tampered hash with the expected length", () => {
    const hash = hashOtp("482901");
    const tamperedHash = `${hash.slice(0, -1)}${hash.endsWith("0") ? "1" : "0"}`;

    expect(tamperedHash).toHaveLength(hash.length);
    expect(verifyOtp("482901", tamperedHash)).toBe(false);
  });

  it("rejects a stored hash with the wrong length", () => {
    expect(verifyOtp("482901", "not-a-sha256-hash")).toBe(false);
  });
});