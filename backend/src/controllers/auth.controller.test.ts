import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const { TokenExpiredError, JsonWebTokenError, jwtDecode } = vi.hoisted(() => {
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
  return { TokenExpiredError, JsonWebTokenError, jwtDecode: vi.fn() };
});

const { signAccessToken, signRefreshToken, verifyRefreshToken } = vi.hoisted(() => ({
  signAccessToken: vi.fn(),
  signRefreshToken: vi.fn(),
  verifyRefreshToken: vi.fn(),
}));

const { bcryptHash, bcryptCompare } = vi.hoisted(() => ({
  bcryptHash: vi.fn(),
  bcryptCompare: vi.fn(),
}));

const {
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
} = vi.hoisted(() => ({
  findByEmail: vi.fn(),
  findByMobile: vi.fn(),
  findByEmailOrMobile: vi.fn(),
  findById: vi.fn(),
  findRefreshToken: vi.fn(),
  saveRefreshToken: vi.fn(),
  deleteRefreshToken: vi.fn(),
  deleteRefreshTokensByUser: vi.fn(),
  updateLastLogin: vi.fn(),
  createUser: vi.fn(),
}));

vi.mock("jsonwebtoken", () => ({
  default: { decode: jwtDecode },
  TokenExpiredError,
  JsonWebTokenError,
}));

vi.mock("../lib/jwt.js", () => ({
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
}));

vi.mock("bcrypt", () => ({
  default: { hash: bcryptHash, compare: bcryptCompare },
}));

vi.mock("node:crypto", () => ({
  randomUUID: vi.fn().mockReturnValue("test-jti-uuid"),
}));

vi.mock("../services/user.service.js", () => ({
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
}));

vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import { register, login, refresh, logout } from "./auth.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq({
  body = {} as Record<string, unknown>,
  userId = "user-1",
} = {}): Request {
  return {
    log: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
    user: { id: userId },
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
    mobile: "+2348012345678",
    password_hash: "$2b$12$hashedpassword",
    status: "active",
    country: null,
    avatar: null,
    created_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// register
// ---------------------------------------------------------------------------

describe("register", () => {
  it("returns 201 with player_id on successful registration (email + mobile)", async () => {
    const user = makeUser();
    findByEmail.mockResolvedValue(null);
    findByMobile.mockResolvedValue(null);
    bcryptHash.mockResolvedValue("$2b$12$hashed");
    createUser.mockResolvedValue(user);

    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", email: "alice@example.com", mobile: "+2348012345678", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        player_id: user.player_id,
        full_name: user.full_name,
        message: "Registration successful.",
      },
    });
  });

  it("registers with email only (no mobile)", async () => {
    findByEmail.mockResolvedValue(null);
    bcryptHash.mockResolvedValue("$2b$12$hashed");
    createUser.mockResolvedValue(makeUser());

    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", email: "alice@example.com", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(201);
    expect(findByMobile).not.toHaveBeenCalled();
  });

  it("registers with mobile only (no email)", async () => {
    findByMobile.mockResolvedValue(null);
    bcryptHash.mockResolvedValue("$2b$12$hashed");
    createUser.mockResolvedValue(makeUser());

    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", mobile: "+2348012345678", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(201);
    expect(findByEmail).not.toHaveBeenCalled();
  });

  it("returns 400 when full_name is missing", async () => {
    const res = makeRes();
    await register(makeReq({ body: { email: "a@b.com", password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when full_name is too short (< 2 chars)", async () => {
    const res = makeRes();
    await register(makeReq({ body: { full_name: "A", email: "a@b.com", password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when full_name exceeds 120 characters", async () => {
    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "A".repeat(121), email: "a@b.com", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when neither email nor mobile is provided", async () => {
    const res = makeRes();
    await register(makeReq({ body: { full_name: "Alice Test", password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when email format is invalid", async () => {
    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", email: "not-an-email", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when mobile format is invalid (missing + prefix)", async () => {
    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", mobile: "08012345678", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when password is missing", async () => {
    const res = makeRes();
    await register(makeReq({ body: { full_name: "Alice Test", email: "a@b.com" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when password is too short (< 8 chars)", async () => {
    const res = makeRes();
    await register(makeReq({ body: { full_name: "Alice Test", email: "a@b.com", password: "Ab1" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when password has no letter", async () => {
    const res = makeRes();
    await register(makeReq({ body: { full_name: "Alice Test", email: "a@b.com", password: "12345678" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 400 when password has no digit", async () => {
    const res = makeRes();
    await register(makeReq({ body: { full_name: "Alice Test", email: "a@b.com", password: "Abcdefgh" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 409 when email is already registered", async () => {
    findByEmail.mockResolvedValue(makeUser());

    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", email: "alice@example.com", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Email is already registered." });
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 409 when mobile is already registered", async () => {
    findByMobile.mockResolvedValue(makeUser());

    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", mobile: "+2348012345678", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Mobile number is already registered." });
    expect(createUser).not.toHaveBeenCalled();
  });

  it("returns 500 when createUser throws an unexpected error", async () => {
    findByEmail.mockResolvedValue(null);
    bcryptHash.mockResolvedValue("$2b$12$hashed");
    createUser.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await register(
      makeReq({ body: { full_name: "Alice Test", email: "alice@example.com", password: "Secret123" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// login
// ---------------------------------------------------------------------------

describe("login", () => {
  it("returns 200 with tokens and profile on success", async () => {
    const user = makeUser();
    findByEmailOrMobile.mockResolvedValue(user);
    bcryptCompare.mockResolvedValue(true);
    updateLastLogin.mockResolvedValue(undefined);
    signAccessToken.mockReturnValue("access-token");
    signRefreshToken.mockReturnValue("refresh-token");
    saveRefreshToken.mockResolvedValue(undefined);

    const res = makeRes();
    await login(makeReq({ body: { identifier: "alice@example.com", password: "Secret123" } }), res);

    expect(findByEmailOrMobile).toHaveBeenCalledWith("alice@example.com");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        access_token: "access-token",
        refresh_token: "refresh-token",
        profile: expect.objectContaining({
          id: user.id,
          player_id: user.player_id,
          full_name: user.full_name,
        }),
      },
    });
  });

  it("profile response never includes password_hash", async () => {
    findByEmailOrMobile.mockResolvedValue(makeUser());
    bcryptCompare.mockResolvedValue(true);
    updateLastLogin.mockResolvedValue(undefined);
    signAccessToken.mockReturnValue("access-token");
    signRefreshToken.mockReturnValue("refresh-token");
    saveRefreshToken.mockResolvedValue(undefined);

    const res = makeRes();
    await login(makeReq({ body: { identifier: "alice@example.com", password: "Secret123" } }), res);

    const body = (res.json as ReturnType<typeof vi.fn>).mock.calls[0][0] as {
      data: { profile: Record<string, unknown> };
    };
    expect(body.data.profile).not.toHaveProperty("password_hash");
  });

  it("returns 400 when identifier is missing", async () => {
    const res = makeRes();
    await login(makeReq({ body: { password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmailOrMobile).not.toHaveBeenCalled();
  });

  it("returns 400 when password is missing", async () => {
    const res = makeRes();
    await login(makeReq({ body: { identifier: "alice@example.com" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findByEmailOrMobile).not.toHaveBeenCalled();
  });

  it("returns 401 when user is not found", async () => {
    findByEmailOrMobile.mockResolvedValue(null);

    const res = makeRes();
    await login(makeReq({ body: { identifier: "noone@example.com", password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid credentials." });
  });

  it("returns 401 when password does not match", async () => {
    findByEmailOrMobile.mockResolvedValue(makeUser());
    bcryptCompare.mockResolvedValue(false);

    const res = makeRes();
    await login(makeReq({ body: { identifier: "alice@example.com", password: "WrongPass1" } }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid credentials." });
  });

  it("returns 403 when account is suspended", async () => {
    findByEmailOrMobile.mockResolvedValue(makeUser({ status: "suspended" }));
    bcryptCompare.mockResolvedValue(true);

    const res = makeRes();
    await login(makeReq({ body: { identifier: "alice@example.com", password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Your account has been suspended." });
  });

  it("returns 403 when account is banned", async () => {
    findByEmailOrMobile.mockResolvedValue(makeUser({ status: "banned" }));
    bcryptCompare.mockResolvedValue(true);

    const res = makeRes();
    await login(makeReq({ body: { identifier: "alice@example.com", password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Your account has been banned." });
  });

  it("returns 500 when an unexpected error is thrown", async () => {
    findByEmailOrMobile.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await login(makeReq({ body: { identifier: "alice@example.com", password: "Secret123" } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// refresh
// ---------------------------------------------------------------------------

describe("refresh", () => {
  it("returns 200 with a new access_token on success", async () => {
    const user = makeUser();
    verifyRefreshToken.mockReturnValue({ sub: "user-1", jti: "jti-1" });
    findRefreshToken.mockResolvedValue({ jti: "jti-1" });
    findById.mockResolvedValue(user);
    signAccessToken.mockReturnValue("new-access-token");

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "valid-refresh-token" } }), res);

    expect(signAccessToken).toHaveBeenCalledWith(user.id, user.player_id);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { access_token: "new-access-token" },
    });
  });

  it("returns 400 when refresh_token is missing", async () => {
    const res = makeRes();
    await refresh(makeReq({ body: {} }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(verifyRefreshToken).not.toHaveBeenCalled();
  });

  it("returns 401 when jti is not found in DB (token revoked)", async () => {
    verifyRefreshToken.mockReturnValue({ sub: "user-1", jti: "jti-1" });
    findRefreshToken.mockResolvedValue(null);

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "token" } }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid or revoked refresh token." });
  });

  it("returns 401 when user is not found", async () => {
    verifyRefreshToken.mockReturnValue({ sub: "user-1", jti: "jti-1" });
    findRefreshToken.mockResolvedValue({ jti: "jti-1" });
    findById.mockResolvedValue(null);

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "token" } }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid or revoked refresh token." });
  });

  it("returns 403 when user is suspended", async () => {
    verifyRefreshToken.mockReturnValue({ sub: "user-1", jti: "jti-1" });
    findRefreshToken.mockResolvedValue({ jti: "jti-1" });
    findById.mockResolvedValue(makeUser({ status: "suspended" }));

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "token" } }), res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Your account has been suspended." });
  });

  it("returns 403 when user is banned", async () => {
    verifyRefreshToken.mockReturnValue({ sub: "user-1", jti: "jti-1" });
    findRefreshToken.mockResolvedValue({ jti: "jti-1" });
    findById.mockResolvedValue(makeUser({ status: "banned" }));

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "token" } }), res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Your account has been banned." });
  });

  it("returns 401 when refresh token is expired (TokenExpiredError)", async () => {
    verifyRefreshToken.mockImplementation(() => {
      throw new TokenExpiredError("jwt expired");
    });

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "expired-token" } }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Refresh token has expired." });
  });

  it("returns 401 when refresh token is malformed (JsonWebTokenError)", async () => {
    verifyRefreshToken.mockImplementation(() => {
      throw new JsonWebTokenError("invalid signature");
    });

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "bad-token" } }), res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid refresh token." });
  });

  it("returns 500 on unexpected error", async () => {
    verifyRefreshToken.mockReturnValue({ sub: "user-1", jti: "jti-1" });
    findRefreshToken.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await refresh(makeReq({ body: { refresh_token: "token" } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// logout
// ---------------------------------------------------------------------------

describe("logout", () => {
  it("returns 200 and revokes all tokens when all_devices is true", async () => {
    deleteRefreshTokensByUser.mockResolvedValue(undefined);

    const res = makeRes();
    await logout(makeReq({ body: { all_devices: true } }), res);

    expect(deleteRefreshTokensByUser).toHaveBeenCalledWith("user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, message: "Logged out successfully." });
  });

  it("returns 200 and revokes the specific token when a valid refresh_token is provided", async () => {
    verifyRefreshToken.mockReturnValue({ jti: "jti-1", type: "refresh" });
    deleteRefreshToken.mockResolvedValue(undefined);

    const res = makeRes();
    await logout(makeReq({ body: { refresh_token: "valid-token" } }), res);

    expect(deleteRefreshToken).toHaveBeenCalledWith("jti-1", "user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, message: "Logged out successfully." });
  });

  it("extracts jti via jwt.decode when token is expired (expired tokens still allow logout)", async () => {
    verifyRefreshToken.mockImplementation(() => {
      throw new TokenExpiredError("jwt expired");
    });
    jwtDecode.mockReturnValue({ jti: "jti-expired", type: "refresh" });
    deleteRefreshToken.mockResolvedValue(undefined);

    const res = makeRes();
    await logout(makeReq({ body: { refresh_token: "expired-token" } }), res);

    expect(deleteRefreshToken).toHaveBeenCalledWith("jti-expired", "user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, message: "Logged out successfully." });
  });

  it("returns 400 when refresh_token is missing and all_devices is not true", async () => {
    const res = makeRes();
    await logout(makeReq({ body: {} }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false }),
    );
    expect(deleteRefreshToken).not.toHaveBeenCalled();
  });

  it("returns 400 when token decode returns null (completely invalid structure)", async () => {
    verifyRefreshToken.mockImplementation(() => {
      throw new JsonWebTokenError("invalid token");
    });
    jwtDecode.mockReturnValue(null);

    const res = makeRes();
    await logout(makeReq({ body: { refresh_token: "garbage" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid refresh token." });
  });

  it("returns 400 when decoded token is missing jti", async () => {
    verifyRefreshToken.mockImplementation(() => {
      throw new JsonWebTokenError("invalid");
    });
    jwtDecode.mockReturnValue({ type: "refresh" }); // no jti

    const res = makeRes();
    await logout(makeReq({ body: { refresh_token: "no-jti-token" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Invalid refresh token." });
  });

  it("returns 500 on unexpected error", async () => {
    deleteRefreshTokensByUser.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await logout(makeReq({ body: { all_devices: true } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
