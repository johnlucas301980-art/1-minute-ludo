import { describe, expect, it, vi } from "vitest";

import healthRouter from "./health.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type RouterLayer = {
  route?: {
    path: string;
    methods: Record<string, boolean>;
    stack: Array<{ handle: (...args: unknown[]) => unknown }>;
  };
};

function routerStack(): RouterLayer[] {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (healthRouter as any).stack as RouterLayer[];
}

function makeRes() {
  const res = { json: vi.fn() };
  return res;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("health router", () => {
  it("registers a GET /healthz route", () => {
    const layer = routerStack().find(
      (l) => l.route?.path === "/healthz" && l.route.methods["get"] === true,
    );
    expect(layer).toBeDefined();
  });

  it("GET /healthz handler responds with { status: 'ok' }", () => {
    const layer = routerStack().find((l) => l.route?.path === "/healthz");
    const handler = layer?.route?.stack[0]?.handle;
    expect(handler).toBeTypeOf("function");

    const req = {};
    const res = makeRes();
    handler!(req, res);

    expect(res.json).toHaveBeenCalledOnce();
    expect(res.json).toHaveBeenCalledWith({ status: "ok" });
  });
});
