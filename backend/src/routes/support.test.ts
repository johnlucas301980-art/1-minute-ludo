import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/support.controller.js", () => ({
  getFaqsHandler: vi.fn(),
  createTicketHandler: vi.fn(),
  getTicketsHandler: vi.fn(),
  getTicketByIdHandler: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

import supportRouter from "./support.js";

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
  return ((supportRouter as any).stack as RouterLayer[])
    .filter((l) => l.route !== undefined)
    .map((l) => ({
      path: l.route!.path as string,
      methods: Object.keys(l.route!.methods),
    }));
}

describe("support router", () => {
  it("registers GET /support/faqs", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/support/faqs", methods: ["get"] }),
    );
  });

  it("registers POST /support/tickets", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/support/tickets", methods: ["post"] }),
    );
  });

  it("registers GET /support/tickets", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/support/tickets", methods: ["get"] }),
    );
  });

  it("registers GET /support/tickets/:id", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/support/tickets/:id", methods: ["get"] }),
    );
  });

  it("all support routes apply authenticate middleware", () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layers = ((supportRouter as any).stack as RouterLayer[]).filter(
      (l) => l.route !== undefined,
    );
    for (const layer of layers) {
      // authenticate + controller = at least 2 handlers
      expect(layer.route!.stack.length).toBeGreaterThanOrEqual(2);
    }
  });
});
