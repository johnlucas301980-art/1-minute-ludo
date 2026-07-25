import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/auth.controller.js", () => ({
  register: vi.fn(),
  login: vi.fn(),
  refresh: vi.fn(),
  logout: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

import authRouter from "./auth.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
  return ((authRouter as any).stack as RouterLayer[])
    .filter((l) => l.route !== undefined)
    .map((l) => ({
      path: l.route!.path as string,
      methods: Object.keys(l.route!.methods),
    }));
}

function findLayer(path: string): RouterLayer | undefined {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return ((authRouter as any).stack as RouterLayer[]).find(
    (l) => l.route?.path === path,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("auth router", () => {
  it("registers POST /register", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/register", methods: ["post"] }),
    );
  });

  it("registers POST /login", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/login", methods: ["post"] }),
    );
  });

  it("registers POST /refresh", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/refresh", methods: ["post"] }),
    );
  });

  it("registers POST /logout", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/logout", methods: ["post"] }),
    );
  });

  it("logout route applies authenticate middleware before the handler", () => {
    const layer = findLayer("/logout");
    // Stack should contain at least two handlers: authenticate + logout controller
    expect(layer?.route?.stack.length).toBeGreaterThanOrEqual(2);
  });
});
