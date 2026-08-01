import { describe, expect, it, vi } from "vitest";

// Mock every sub-router so this test only validates the index aggregation layer.
vi.mock("./health.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./auth.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./password_reset.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./profile.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./wallet.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./matchmaking.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./history.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./leaderboard.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./notifications.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./support.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./admin.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./country.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});
vi.mock("./game.js", async () => {
  const { Router } = await import("express");
  return { default: Router() };
});

import indexRouter from "./index.js";

type Layer = { route?: unknown; handle?: unknown };

describe("routes index", () => {
  it("mounts all 12 sub-routers", () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layers = (indexRouter as any).stack as Layer[];
    expect(layers.length).toBe(13);
  });

  it("all layers are middleware mounts with no direct route definitions", () => {
    // Every layer comes from router.use() — none from router.get/post/etc.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layers = (indexRouter as any).stack as Layer[];
    expect(layers.every((l) => l.route === undefined)).toBe(true);
  });
});
