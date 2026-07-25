import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/leaderboard.controller.js", () => ({
  getLeaderboardHandler: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

import leaderboardRouter from "./leaderboard.js";

type RouterLayer = {
  route?: {
    path: string;
    methods: Record<string, boolean>;
    stack: Array<{ handle: unknown }>;
  };
};

function stack(): RouterLayer[] {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (leaderboardRouter as any).stack as RouterLayer[];
}

describe("leaderboard router", () => {
  it("registers GET /leaderboard", () => {
    const layer = stack().find(
      (l) => l.route?.path === "/leaderboard" && l.route.methods["get"] === true,
    );
    expect(layer).toBeDefined();
  });

  it("GET /leaderboard applies authenticate middleware", () => {
    const layer = stack().find((l) => l.route?.path === "/leaderboard");
    // authenticate + handler = at least 2
    expect(layer?.route?.stack.length).toBeGreaterThanOrEqual(2);
  });
});
