import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const { TokenExpiredError, JsonWebTokenError } = vi.hoisted(() => {
  class TokenExpiredError extends Error {
    expiredAt: Date;
    constructor(message: string, expiredAt = new Date()) {
      super(message);
      this.name = "TokenExpiredError";
      this.expiredAt = expiredAt;
    }
  }
  class JsonWebTokenError extends Error {
    constructor(message: string) {
      super(message);
      this.name = "JsonWebTokenError";
    }
  }
  return { TokenExpiredError, JsonWebTokenError };
});

const { generateOtp, hashOtp, verifyOtp } = vi.hoisted(() => ({
  generateOtp: vi.fn(),
  hashOtp: vi.fn(),
  verifyOtp: vi.fn(),
}));

const { sendPasswordResetEmail } = vi.hoisted(() => ({
  sendPasswordResetEmail: vi.fn(),
}));

const { signPasswordResetToken, verifyPasswordResetToken } = vi.hoisted(() => ({
  signPasswordResetToken: vi.fn(),
  verifyPasswordResetToken: vi.fn(),
}));

const { findByEmail, findById } = vi.hoisted(() => ({
  findByEmail: vi.fn(),
  findById: vi.fn(),
}));

const {
  countRecentOtpRequests,
  createOtp,
  incrementLatestOtpAttempt,
  findOtpById,
  applyPasswordReset,
  MAX_ATTEMPTS,
  MAX_REQUESTS_PER_HOUR,
} = vi.hoisted(() => ({
  countRecentOtpRequests: vi.fn(),
  createOtp: vi.fn(),
  incrementLatestOtpAttempt: vi.fn(),
  findOtpById: vi.fn(),
  applyPasswordReset: vi.fn(),
  // Match production values: password_reset.service.ts
  MAX_ATTEMPTS: 5,
  MAX_REQUESTS_PER_HOUR: 3,
}));

const { bcryptHash } = vi.hoisted(() => ({
  bcryptHash: vi.fn(),
}));

vi.mock("jsonwebtoken", () => ({
  default: {},
  TokenExpiredError,
  JsonWebTokenError,
}));

vi.mock("../lib/otp.js", () => ({
  generateOtp,
  hashOtp,
  verifyOtp,
}));

vi.mock("../lib/email.js", () => ({
  sendPasswordResetEmail,
}));

vi.mock("../lib/jwt.js", () => ({
  signPasswordResetToken,
  verifyPasswordResetToken,
}));

vi.mock("../services/user.service.js", () => ({
  findByEmail,
  findById,
}));

vi.mock("../services/password_reset.service.js", () => ({
  countRecentOtpRequests,
  createOtp,
  incrementLatestOtpAttempt,
  findOtpById,
  applyPasswordReset,
  MAX_ATTEMPTS,
  MAX_REQUESTS_PER_HOUR,
}));

vi.mock("bcrypt", () => ({
  default: { hash: bcryptHash },
}));

vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import {
  requestPasswordReset,
  verifyPasswordResetOtp,
  confirmPasswordReset,
} from "./password_reset.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const VALID_UUID = "550e8400-e29b-41d4-a716-446655440000";

const SAFE_RESPONSE = {
  success: true,
  message: "If that email is registered, an OTP has been sent.",
};

function makeReq(body: Record<string, unknown> = {}): Request {
  return {
    log: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
    body,
  } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

function makeUser(overrides = {}) {
  return {
    id: "user-1",
    player_id: "LUD-001",
    full_name: "Alice Test",
    email: "alice@example.com",
    status: "active",
    password_hash: "$2b$12$hashed",
    ...overrides,
  };
}

function makeOtpRow(overrides = {}) {
  return {
    id: VALID_UUID,
    user_id: "user-1",
    otp_hash: "hashed-otp",
    attempts: 1,
    used_at: null,
    expires_at: new Date(Date.now() + 10 * 60 * 1000), // 10 min from now
    created_at: new Date(),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// requestPasswordReset
// ---------------------------------------------------------------------------

describe("requestPasswordReset", () => {
  it("returns 200 safe response when email is found and OTP is created", async () => {
    findByEmail.mockResolvedValue(makeUser());
    countRecentOtpRequests.mockResolvedValue(0);
    generateOtp.mockReturnValue("123456");
    hashOtp.mockReturnValue("hashed-otp");
    createOtp.mockResolvedValue(undefined);
    sendPasswordResetEmail.mockResolvedValue(undefined);

    const res = makeRes();
    await requestPasswordReset(makeReq({ email: "alice@example.com" }), res);

    expect(createOtp).toHaveBeenCalledWith("user-1", "hashed-otp");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(SAFE_RESPONSE);
  });

  it("returns 200 safe response when email is NOT found (prevents account enumeration)", async () => {
    findByEmail.mockResolvedValue(null);

    const res = makeRes();
    await requestPasswordReset(makeReq({ email: "nobody@example.com" }), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(SAFE_RESPONSE);
    expect(createOtp).not.toHaveBeenCalled();
  });

  it("returns 400 when email is missing", async () => {
    const res = makeRes();
    await requestPasswordReset(makeReq({}), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmail).not.toHaveBeenCalled();
  });

  it("returns 400 when email format is invalid", async () => {
    const res = makeRes();
    await requestPasswordReset(makeReq({ email: "not-an-email" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmail).not.toHaveBeenCalled();
  });

  it("returns 429 when rate limit is exceeded", async () => {
    findByEmail.mockResolvedValue(makeUser());
    countRecentOtpRequests.mockResolvedValue(MAX_REQUESTS_PER_HOUR); // >= limit

    const res = makeRes();
    await requestPasswordReset(makeReq({ email: "alice@example.com" }), res);

    expect(res.status).toHaveBeenCalledWith(429);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Too many password reset requests. Please wait before trying again.",
    });
    expect(createOtp).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error", async () => {
    findByEmail.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await requestPasswordReset(makeReq({ email: "alice@example.com" }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// verifyPasswordResetOtp
// ---------------------------------------------------------------------------

describe("verifyPasswordResetOtp", () => {
  it("returns 200 with reset_token on correct OTP", async () => {
    const otpRow = makeOtpRow({ attempts: 1 });
    findByEmail.mockResolvedValue(makeUser());
    incrementLatestOtpAttempt.mockResolvedValue(otpRow);
    verifyOtp.mockReturnValue(true);
    signPasswordResetToken.mockReturnValue("reset-token");

    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "alice@example.com", otp: "123456" }), res);

    expect(signPasswordResetToken).toHaveBeenCalledWith("user-1", otpRow.id);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { reset_token: "reset-token" },
    });
  });

  it("returns 400 when email is missing", async () => {
    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ otp: "123456" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmail).not.toHaveBeenCalled();
  });

  it("returns 400 when email format is invalid", async () => {
    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "bad-email", otp: "123456" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmail).not.toHaveBeenCalled();
  });

  it("returns 400 when otp is missing", async () => {
    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "alice@example.com" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmail).not.toHaveBeenCalled();
  });

  it("returns 400 when otp is not exactly 6 digits", async () => {
    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "alice@example.com", otp: "1234" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmail).not.toHaveBeenCalled();
  });

  it("returns 400 when user is not found (generic error prevents enumeration)", async () => {
    findByEmail.mockResolvedValue(null);

    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "nobody@example.com", otp: "123456" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "OTP is invalid or has expired." });
  });

  it("returns 400 when no valid OTP row exists in the database", async () => {
    findByEmail.mockResolvedValue(makeUser());
    incrementLatestOtpAttempt.mockResolvedValue(null);

    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "alice@example.com", otp: "123456" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "OTP is invalid or has expired." });
  });

  it("returns 400 with 'OTP is incorrect' when OTP is wrong and below max attempts", async () => {
    findByEmail.mockResolvedValue(makeUser());
    incrementLatestOtpAttempt.mockResolvedValue(makeOtpRow({ attempts: 1 }));
    verifyOtp.mockReturnValue(false);

    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "alice@example.com", otp: "000000" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "OTP is incorrect." });
  });

  it("returns 400 with lockout message when max attempts are reached", async () => {
    findByEmail.mockResolvedValue(makeUser());
    // attempts equals MAX_ATTEMPTS (5) — triggers lockout message
    incrementLatestOtpAttempt.mockResolvedValue(makeOtpRow({ attempts: MAX_ATTEMPTS }));
    verifyOtp.mockReturnValue(false);

    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "alice@example.com", otp: "000000" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Too many failed attempts. Please request a new OTP.",
    });
  });

  it("returns 500 on unexpected error", async () => {
    findByEmail.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await verifyPasswordResetOtp(makeReq({ email: "alice@example.com", otp: "123456" }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// confirmPasswordReset
// ---------------------------------------------------------------------------

describe("confirmPasswordReset", () => {
  it("returns 200 on successful password reset", async () => {
    const user = makeUser();
    const otpRow = makeOtpRow();
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockResolvedValue(user);
    findOtpById.mockResolvedValue(otpRow);
    bcryptHash.mockResolvedValue("$2b$12$newhashedpassword");
    applyPasswordReset.mockResolvedValue(undefined);

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(applyPasswordReset).toHaveBeenCalledWith("user-1", VALID_UUID, "$2b$12$newhashedpassword");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, message: "Password updated successfully." });
  });

  it("returns 400 when reset_token is missing", async () => {
    const res = makeRes();
    await confirmPasswordReset(makeReq({ new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(verifyPasswordResetToken).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password is missing", async () => {
    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "token" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(verifyPasswordResetToken).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password is too short (< 8 chars)", async () => {
    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "token", new_password: "Ab1" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(verifyPasswordResetToken).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password has no letter", async () => {
    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "token", new_password: "12345678" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(verifyPasswordResetToken).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password has no digit", async () => {
    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "token", new_password: "Abcdefgh" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(verifyPasswordResetToken).not.toHaveBeenCalled();
  });

  it("returns 401 when reset_token is expired (TokenExpiredError)", async () => {
    verifyPasswordResetToken.mockImplementation(() => {
      throw new TokenExpiredError("jwt expired");
    });

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "expired-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Reset token has expired." });
  });

  it("returns 401 when reset_token is malformed (JsonWebTokenError)", async () => {
    verifyPasswordResetToken.mockImplementation(() => {
      throw new JsonWebTokenError("invalid signature");
    });

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "bad-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid reset token." });
  });

  it("returns 401 when user is not found after token verification", async () => {
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockResolvedValue(null);

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid reset token." });
  });

  it("returns 403 when account is suspended", async () => {
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockResolvedValue(makeUser({ status: "suspended" }));

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Your account has been suspended." });
  });

  it("returns 403 when account is banned", async () => {
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockResolvedValue(makeUser({ status: "banned" }));

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Your account has been banned." });
  });

  it("returns 400 when OTP row is not found", async () => {
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockResolvedValue(makeUser());
    findOtpById.mockResolvedValue(null);

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Reset session is no longer valid. Please request a new OTP.",
    });
  });

  it("returns 400 when OTP row has already been used", async () => {
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockResolvedValue(makeUser());
    findOtpById.mockResolvedValue(makeOtpRow({ used_at: new Date("2026-01-01") }));

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Reset session is no longer valid. Please request a new OTP.",
    });
  });

  it("returns 400 when OTP row has expired", async () => {
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockResolvedValue(makeUser());
    findOtpById.mockResolvedValue(makeOtpRow({ expires_at: new Date(Date.now() - 1000) }));

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Reset session is no longer valid. Please request a new OTP.",
    });
  });

  it("returns 500 on unexpected error", async () => {
    verifyPasswordResetToken.mockReturnValue({ sub: "user-1", otp_id: VALID_UUID });
    findById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await confirmPasswordReset(makeReq({ reset_token: "valid-token", new_password: "NewPass123" }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
