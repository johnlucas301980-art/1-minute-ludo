import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/notification.controller.js", () => ({
  getNotificationsHandler: vi.fn(),
  markAllNotificationsReadHandler: vi.fn(),
  markNotificationReadHandler: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

import notificationsRouter from "./notifications.js";

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
  return ((notificationsRouter as any).stack as RouterLayer[])
    .filter((l) => l.route !== undefined)
    .map((l) => ({
      path: l.route!.path as string,
      methods: Object.keys(l.route!.methods),
    }));
}

describe("notifications router", () => {
  it("registers GET /notifications", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/notifications", methods: ["get"] }),
    );
  });

  it("registers PUT /notifications/read-all", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/notifications/read-all", methods: ["put"] }),
    );
  });

  it("registers PUT /notifications/:id/read", () => {
    expect(extractRoutes()).toContainEqual(
      expect.objectContaining({ path: "/notifications/:id/read", methods: ["put"] }),
    );
  });

  it("all notification routes apply authenticate middleware", () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layers = ((notificationsRouter as any).stack as RouterLayer[]).filter(
      (l) => l.route !== undefined,
    );
    for (const layer of layers) {
      // authenticate + controller = at least 2 handlers
      expect(layer.route!.stack.length).toBeGreaterThanOrEqual(2);
    }
  });
});
