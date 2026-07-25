import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/profile.controller.js", () => ({
  getProfile: vi.fn(),
  updateProfile: vi.fn(),
  changePassword: vi.fn(),
  uploadAvatar: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

vi.mock("multer", () => ({
  default: Object.assign(vi.fn(), {
    MulterError: class MulterError extends Error {
      code: string;
      constructor(code: string) {
        super(code);
        this.code = code;
      }
    },
  }),
}));

vi.mock("../lib/upload.js", () => ({
  avatarUpload: { single: vi.fn().mockReturnValue(vi.fn()) },
}));

import profileRouter from "./profile.js";

type RouteEntry = { path: string; methods: string[] };

type RouterLayer = {
  route?: {
    path: string;
    methods: Record<string, boolean>;
    stack: Array<{ handle: unknown }>;
  };
};

function extractRoutes(): RouteEntry[] {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return ((profileRouter as any).stack as RouterLayer[])
    .filter((l) => l.route !== undefined)
    .map((l) => ({
      path: l.route!.path as string,
      methods: Object.keys(l.route!.methods),
    }));
}

function findLayer(path: string): RouterLayer | undefined {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return ((profileRouter as any).stack as RouterLayer[]).find(
    (l) => l.route?.path === path,
  );
}

describe("profile router", () => {
  it("registers GET /profile", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/profile", methods: ["get"] }),
    );
  });

  it("registers PUT /profile", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/profile", methods: ["put"] }),
    );
  });

  it("registers PUT /profile/password", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/profile/password", methods: ["put"] }),
    );
  });

  it("registers PUT /profile/avatar", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/profile/avatar", methods: ["put"] }),
    );
  });

  it("PUT /profile/avatar has extra middleware for upload handling", () => {
    const layer = findLayer("/profile/avatar");
    // authenticate + handleAvatarUpload + uploadAvatar = at least 3 handlers
    expect(layer?.route?.stack.length).toBeGreaterThanOrEqual(3);
  });
});
