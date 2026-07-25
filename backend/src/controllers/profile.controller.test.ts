import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const { findProfileById, updateProfileById } = vi.hoisted(() => ({
  findProfileById: vi.fn(),
  updateProfileById: vi.fn(),
}));

const { findById, updatePasswordById, deleteRefreshTokensByUser } = vi.hoisted(() => ({
  findById: vi.fn(),
  updatePasswordById: vi.fn(),
  deleteRefreshTokensByUser: vi.fn(),
}));

const { bcryptHash, bcryptCompare } = vi.hoisted(() => ({
  bcryptHash: vi.fn(),
  bcryptCompare: vi.fn(),
}));

const { pathExtname, pathJoin } = vi.hoisted(() => ({
  pathExtname: vi.fn(),
  pathJoin: vi.fn(),
}));

const { fsUnlink } = vi.hoisted(() => ({
  fsUnlink: vi.fn(),
}));

vi.mock("../services/profile.service.js", () => ({
  findProfileById,
  updateProfileById,
}));

vi.mock("../services/user.service.js", () => ({
  findById,
  updatePasswordById,
  deleteRefreshTokensByUser,
}));

vi.mock("bcrypt", () => ({
  default: { hash: bcryptHash, compare: bcryptCompare },
}));

vi.mock("node:path", () => ({
  default: { extname: pathExtname, join: pathJoin },
}));

vi.mock("node:fs", () => ({
  default: { unlink: fsUnlink },
}));

vi.mock("../lib/upload.js", () => ({
  AVATARS_DIR: "/uploads/avatars",
  MIME_TO_EXT: { "image/jpeg": ".jpg", "image/png": ".png" },
}));

vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import {
  getProfile,
  updateProfile,
  changePassword,
  uploadAvatar,
} from "./profile.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const VALID_UUID = "550e8400-e29b-41d4-a716-446655440000";

function makeReq({
  userId = "user-1",
  body = {} as Record<string, unknown>,
  query = {} as Record<string, string>,
  params = {} as Record<string, string>,
  file = undefined as Express.Multer.File | undefined,
  protocol = "http",
  host = "localhost:5000",
} = {}): Request {
  return {
    log: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
    user: { id: userId },
    body,
    query,
    params,
    file,
    protocol,
    get: vi.fn().mockReturnValue(host),
  } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

function makeProfile(overrides = {}) {
  return {
    id: "user-1",
    player_id: "LUD-001",
    full_name: "Alice Test",
    email: "alice@example.com",
    mobile: null,
    country: null,
    avatar: null,
    status: "active",
    role: "player",
    created_at: new Date("2026-01-01T00:00:00Z"),
    last_login_at: null,
    ...overrides,
  };
}

function makeUser(overrides = {}) {
  return {
    id: "user-1",
    player_id: "LUD-001",
    full_name: "Alice Test",
    email: "alice@example.com",
    password_hash: "$2b$12$currenthash",
    status: "active",
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// getProfile
// ---------------------------------------------------------------------------

describe("getProfile", () => {
  it("returns 200 with the player profile", async () => {
    const profile = makeProfile();
    findProfileById.mockResolvedValue(profile);

    const res = makeRes();
    await getProfile(makeReq(), res);

    expect(findProfileById).toHaveBeenCalledWith("user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { profile } });
  });

  it("returns 404 when profile is not found", async () => {
    findProfileById.mockResolvedValue(null);

    const res = makeRes();
    await getProfile(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Profile not found." });
  });

  it("returns 500 on unexpected error", async () => {
    findProfileById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getProfile(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// updateProfile
// ---------------------------------------------------------------------------

describe("updateProfile", () => {
  it("returns 200 with updated profile on success", async () => {
    const profile = makeProfile({ full_name: "Bob Test" });
    updateProfileById.mockResolvedValue(profile);

    const res = makeRes();
    await updateProfile(makeReq({ body: { full_name: "Bob Test" } }), res);

    expect(updateProfileById).toHaveBeenCalledWith("user-1", {
      full_name: "Bob Test",
      country: undefined,
      avatar: undefined,
    });
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { profile } });
  });

  it("accepts country as null to clear it", async () => {
    updateProfileById.mockResolvedValue(makeProfile({ country: null }));

    const res = makeRes();
    await updateProfile(makeReq({ body: { country: null } }), res);

    expect(updateProfileById).toHaveBeenCalledWith(
      "user-1",
      expect.objectContaining({ country: null }),
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("accepts avatar as null to clear it", async () => {
    updateProfileById.mockResolvedValue(makeProfile({ avatar: null }));

    const res = makeRes();
    await updateProfile(makeReq({ body: { avatar: null } }), res);

    expect(updateProfileById).toHaveBeenCalledWith(
      "user-1",
      expect.objectContaining({ avatar: null }),
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when no fields are provided", async () => {
    const res = makeRes();
    await updateProfile(makeReq({ body: {} }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 400 when full_name is empty string", async () => {
    const res = makeRes();
    await updateProfile(makeReq({ body: { full_name: "   " } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 400 when full_name is too short (< 2 chars)", async () => {
    const res = makeRes();
    await updateProfile(makeReq({ body: { full_name: "A" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 400 when full_name exceeds 120 characters", async () => {
    const res = makeRes();
    await updateProfile(makeReq({ body: { full_name: "A".repeat(121) } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 400 when country is an empty string (not null)", async () => {
    const res = makeRes();
    await updateProfile(makeReq({ body: { country: "" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 400 when avatar is not a valid URL", async () => {
    const res = makeRes();
    await updateProfile(makeReq({ body: { avatar: "not-a-url" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 400 when avatar is an empty string (not null)", async () => {
    const res = makeRes();
    await updateProfile(makeReq({ body: { avatar: "" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 404 when updateProfileById returns null", async () => {
    updateProfileById.mockResolvedValue(null);

    const res = makeRes();
    await updateProfile(makeReq({ body: { full_name: "Alice Test" } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Profile not found." });
  });

  it("returns 500 on unexpected error", async () => {
    updateProfileById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await updateProfile(makeReq({ body: { full_name: "Alice Test" } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// changePassword
// ---------------------------------------------------------------------------

describe("changePassword", () => {
  it("returns 200 on successful password change", async () => {
    findById.mockResolvedValue(makeUser());
    bcryptCompare.mockResolvedValue(true);
    bcryptHash.mockResolvedValue("$2b$12$newhash");
    updatePasswordById.mockResolvedValue(undefined);
    deleteRefreshTokensByUser.mockResolvedValue(undefined);

    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "OldPass1", new_password: "NewPass2" } }),
      res,
    );

    expect(updatePasswordById).toHaveBeenCalledWith("user-1", "$2b$12$newhash");
    expect(deleteRefreshTokensByUser).toHaveBeenCalledWith("user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, message: "Password changed successfully." });
  });

  it("returns 400 when current_password is missing", async () => {
    const res = makeRes();
    await changePassword(makeReq({ body: { new_password: "NewPass2" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findById).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password is missing", async () => {
    const res = makeRes();
    await changePassword(makeReq({ body: { current_password: "OldPass1" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findById).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password is too short (< 8 chars)", async () => {
    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "OldPass1", new_password: "Ab1" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findById).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password has no letter", async () => {
    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "OldPass1", new_password: "12345678" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findById).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password has no digit", async () => {
    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "OldPass1", new_password: "Abcdefgh" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findById).not.toHaveBeenCalled();
  });

  it("returns 400 when new_password equals current_password", async () => {
    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "SamePass1", new_password: "SamePass1" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(findById).not.toHaveBeenCalled();
  });

  it("returns 404 when user is not found", async () => {
    findById.mockResolvedValue(null);

    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "OldPass1", new_password: "NewPass2" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Profile not found." });
  });

  it("returns 401 when current password is incorrect", async () => {
    findById.mockResolvedValue(makeUser());
    bcryptCompare.mockResolvedValue(false);

    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "WrongPass1", new_password: "NewPass2" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Current password is incorrect.",
    });
  });

  it("returns 500 on unexpected error", async () => {
    findById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await changePassword(
      makeReq({ body: { current_password: "OldPass1", new_password: "NewPass2" } }),
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
// uploadAvatar
// ---------------------------------------------------------------------------

describe("uploadAvatar", () => {
  function makeFile(filename = "user-1.jpg"): Express.Multer.File {
    return {
      filename,
      originalname: "avatar.jpg",
      mimetype: "image/jpeg",
      size: 102400,
      fieldname: "avatar",
      encoding: "7bit",
      destination: "/uploads/avatars",
      path: `/uploads/avatars/${filename}`,
      buffer: Buffer.alloc(0),
      stream: null as never,
    };
  }

  it("returns 200 with avatar URL on success", async () => {
    pathExtname.mockReturnValue(".jpg");
    pathJoin.mockReturnValue("/uploads/avatars/user-1.png");
    fsUnlink.mockImplementation((_path: string, cb: () => void) => cb());
    updateProfileById.mockResolvedValue(makeProfile({ avatar: "http://localhost:5000/uploads/avatars/user-1.jpg" }));

    const res = makeRes();
    await uploadAvatar(makeReq({ file: makeFile("user-1.jpg") }), res);

    expect(updateProfileById).toHaveBeenCalledWith(
      "user-1",
      { avatar: "http://localhost:5000/uploads/avatars/user-1.jpg" },
    );
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { avatar: "http://localhost:5000/uploads/avatars/user-1.jpg" },
    });
  });

  it("returns 400 when no file is attached", async () => {
    const res = makeRes();
    await uploadAvatar(makeReq({ file: undefined }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: 'No file uploaded. Attach an image file in the "avatar" form field.',
    });
    expect(updateProfileById).not.toHaveBeenCalled();
  });

  it("returns 404 when updateProfileById returns null", async () => {
    pathExtname.mockReturnValue(".jpg");
    pathJoin.mockReturnValue("/uploads/avatars/user-1.png");
    fsUnlink.mockImplementation((_path: string, cb: () => void) => cb());
    updateProfileById.mockResolvedValue(null);

    const res = makeRes();
    await uploadAvatar(makeReq({ file: makeFile("user-1.jpg") }), res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "Profile not found." });
  });

  it("returns 500 on unexpected error", async () => {
    pathExtname.mockReturnValue(".jpg");
    pathJoin.mockReturnValue("/uploads/avatars/user-1.png");
    fsUnlink.mockImplementation((_path: string, cb: () => void) => cb());
    updateProfileById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await uploadAvatar(makeReq({ file: makeFile("user-1.jpg") }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
