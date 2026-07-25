import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/wallet.controller.js", () => ({
  getWallet: vi.fn(),
  getWalletHistory: vi.fn(),
  deposit: vi.fn(),
  withdraw: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

import walletRouter from "./wallet.js";

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
  return ((walletRouter as any).stack as RouterLayer[])
    .filter((l) => l.route !== undefined)
    .map((l) => ({
      path: l.route!.path as string,
      methods: Object.keys(l.route!.methods),
    }));
}

describe("wallet router", () => {
  it("registers GET /wallet", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/wallet", methods: ["get"] }),
    );
  });

  it("registers GET /wallet/history", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/wallet/history", methods: ["get"] }),
    );
  });

  it("registers POST /wallet/deposit", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/wallet/deposit", methods: ["post"] }),
    );
  });

  it("registers POST /wallet/withdraw", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/wallet/withdraw", methods: ["post"] }),
    );
  });

  it("all wallet routes apply authenticate middleware", () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layers = ((walletRouter as any).stack as RouterLayer[]).filter(
      (l) => l.route !== undefined,
    );
    for (const layer of layers) {
      // authenticate + controller = at least 2 handlers
      expect(layer.route!.stack.length).toBeGreaterThanOrEqual(2);
    }
  });
});
