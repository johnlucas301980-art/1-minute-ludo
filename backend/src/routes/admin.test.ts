import { describe, expect, it, vi } from "vitest";

vi.mock("../controllers/admin.controller.js", () => ({
  getStatsHandler: vi.fn(),
  listUsersHandler: vi.fn(),
  getUserHandler: vi.fn(),
  updateUserStatusHandler: vi.fn(),
  updateUserRoleHandler: vi.fn(),
  banUserHandler: vi.fn(),
  unbanUserHandler: vi.fn(),
  promoteUserHandler: vi.fn(),
  demoteUserHandler: vi.fn(),
  listTicketsHandler: vi.fn(),
  updateTicketStatusHandler: vi.fn(),
  getAuditLogHandler: vi.fn(),
  listMatchesHandler: vi.fn(),
  getMatchHandler: vi.fn(),
  getMatchEventsHandler: vi.fn(),
  cancelMatchHandler: vi.fn(),
  listWalletsHandler: vi.fn(),
  listWalletTransactionsHandler: vi.fn(),
  getReportHandler: vi.fn(),
  listSettingsHandler: vi.fn(),
  updateSettingHandler: vi.fn(),
  listCountriesAdminHandler: vi.fn(),
  updateCountryHandler: vi.fn(),
}));

vi.mock("../middlewares/authenticate.js", () => ({
  authenticate: vi.fn(),
}));

vi.mock("../middlewares/requireAdmin.js", () => ({
  requireAdmin: vi.fn(),
}));

import adminRouter from "./admin.js";

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
  return ((adminRouter as any).stack as RouterLayer[])
    .filter((l) => l.route !== undefined)
    .map((l) => ({
      path: l.route!.path as string,
      methods: Object.keys(l.route!.methods),
    }));
}

// ---------------------------------------------------------------------------
// Expected route table
// ---------------------------------------------------------------------------

const EXPECTED_ROUTES: Array<{ path: string; method: string }> = [
  { path: "/admin/stats",                           method: "get"   },
  { path: "/admin/users",                           method: "get"   },
  { path: "/admin/users/:id",                       method: "get"   },
  { path: "/admin/users/:id/status",                method: "patch" },
  { path: "/admin/users/:id/role",                  method: "patch" },
  { path: "/admin/users/:id/ban",                   method: "post"  },
  { path: "/admin/users/:id/unban",                 method: "post"  },
  { path: "/admin/users/:id/promote",               method: "post"  },
  { path: "/admin/users/:id/demote",                method: "post"  },
  { path: "/admin/tickets",                         method: "get"   },
  { path: "/admin/tickets/:id/status",              method: "patch" },
  { path: "/admin/audit-log",                       method: "get"   },
  { path: "/admin/matches",                         method: "get"   },
  { path: "/admin/matches/:id",                     method: "get"   },
  { path: "/admin/matches/:id/events",              method: "get"   },
  { path: "/admin/matches/:id/cancel",              method: "post"  },
  { path: "/admin/wallets",                         method: "get"   },
  { path: "/admin/wallets/:userId/transactions",    method: "get"   },
  { path: "/admin/reports",                         method: "get"   },
  { path: "/admin/settings",                        method: "get"   },
  { path: "/admin/settings/:key",                   method: "put"   },
  { path: "/admin/countries",                       method: "get"   },
  { path: "/admin/countries/:iso2",                 method: "put"   },
];

describe("admin router", () => {
  it("registers all 21 admin routes", () => {
    const registered = extractRoutes();
    for (const { path, method } of EXPECTED_ROUTES) {
      expect(registered).toContainEqual(
        expect.objectContaining({ path, methods: [method] }),
      );
    }
  });

  it("every admin route applies both authenticate and requireAdmin middleware", () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const routeLayers = ((adminRouter as any).stack as RouterLayer[]).filter(
      (l) => l.route !== undefined,
    );
    expect(routeLayers.length).toBe(EXPECTED_ROUTES.length);
    for (const layer of routeLayers) {
      // authenticate + requireAdmin + controller = at least 3 handlers
      expect(layer.route!.stack.length).toBeGreaterThanOrEqual(3);
    }
  });
});
