import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/history.controller.js", () => ({
  getHistory: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

import historyRouter from "./history.js";

type RouterLayer = {
  route?: {
    path: string;
    methods: Record<string, boolean>;
    stack: Array<{ handle: unknown }>;
  };
};

function stack(): RouterLayer[] {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (historyRouter as any).stack as RouterLayer[];
}

describe("history router", () => {
  it("registers GET /match/history", () => {
    const layer = stack().find(
      (l) => l.route?.path === "/match/history" && l.route.methods["get"] === true,
    );
    expect(layer).toBeDefined();
  });

  it("GET /match/history applies authenticate middleware", () => {
    const layer = stack().find((l) => l.route?.path === "/match/history");
    // authenticate + handler = at least 2
    expect(layer?.route?.stack.length).toBeGreaterThanOrEqual(2);
  });
});
