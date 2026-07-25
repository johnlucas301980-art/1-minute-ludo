import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/password_reset.controller.js", () => ({
  requestPasswordReset: vi.fn(),
  verifyPasswordResetOtp: vi.fn(),
  confirmPasswordReset: vi.fn(),
}));

import passwordResetRouter from "./password_reset.js";

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
  return ((passwordResetRouter as any).stack as RouterLayer[])
    .filter((l) => l.route !== undefined)
    .map((l) => ({
      path: l.route!.path as string,
      methods: Object.keys(l.route!.methods),
    }));
}

function findLayer(path: string): RouterLayer | undefined {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return ((passwordResetRouter as any).stack as RouterLayer[]).find(
    (l) => l.route?.path === path,
  );
}

describe("password_reset router", () => {
  it("registers POST /password-reset/request", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/password-reset/request", methods: ["post"] }),
    );
  });

  it("registers POST /password-reset/verify", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/password-reset/verify", methods: ["post"] }),
    );
  });

  it("registers POST /password-reset/confirm", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/password-reset/confirm", methods: ["post"] }),
    );
  });

  it("password reset routes do not require authentication (single handler each)", () => {
    for (const path of [
      "/password-reset/request",
      "/password-reset/verify",
      "/password-reset/confirm",
    ]) {
      const layer = findLayer(path);
      // No authenticate middleware — only the controller handler
      expect(layer?.route?.stack.length).toBe(1);
    }
  });
});
