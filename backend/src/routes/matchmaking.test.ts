import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/matchmaking.controller.js", () => ({
  getQueueStatus: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

import matchmakingRouter from "./matchmaking.js";

type RouterLayer = {
  route?: {
    path: string;
    methods: Record<string, boolean>;
    stack: Array<{ handle: unknown }>;
  };
};

function stack(): RouterLayer[] {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (matchmakingRouter as any).stack as RouterLayer[];
}

describe("matchmaking router", () => {
  it("registers GET /match/queue/status", () => {
    const layer = stack().find(
      (l) => l.route?.path === "/match/queue/status" && l.route.methods["get"] === true,
    );
    expect(layer).toBeDefined();
  });

  it("GET /match/queue/status applies authenticate middleware", () => {
    const layer = stack().find((l) => l.route?.path === "/match/queue/status");
    // authenticate + handler = at least 2
    expect(layer?.route?.stack.length).toBeGreaterThanOrEqual(2);
  });
});
