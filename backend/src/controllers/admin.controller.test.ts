import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const {
  getDashboardStats,
  getUserById,
  listUsers,
  listAllTickets,
  updateTicketStatus,
  updateUserRole,
  updateUserStatus,
  banUser,
  unbanUser,
  promoteUser,
  demoteUser,
  logAdminAction,
  getAuditLog,
  listMatches,
  getMatchById,
  getMatchEvents,
  cancelMatch,
  listWallets,
  listWalletTransactions,
  getAdminReport,
  listSettings,
  updateSetting,
  MATCH_STATUSES,
} = vi.hoisted(() => ({
  getDashboardStats: vi.fn(),
  getUserById: vi.fn(),
  listUsers: vi.fn(),
  listAllTickets: vi.fn(),
  updateTicketStatus: vi.fn(),
  updateUserRole: vi.fn(),
  updateUserStatus: vi.fn(),
  banUser: vi.fn(),
  unbanUser: vi.fn(),
  promoteUser: vi.fn(),
  demoteUser: vi.fn(),
  logAdminAction: vi.fn(),
  getAuditLog: vi.fn(),
  listMatches: vi.fn(),
  getMatchById: vi.fn(),
  getMatchEvents: vi.fn(),
  cancelMatch: vi.fn(),
  listWallets: vi.fn(),
  listWalletTransactions: vi.fn(),
  getAdminReport: vi.fn(),
  listSettings: vi.fn(),
  updateSetting: vi.fn(),
  MATCH_STATUSES: new Set(["waiting", "in_progress", "finished", "cancelled"]),
}));

vi.mock("../services/admin.service.js", () => ({
  getDashboardStats,
  getUserById,
  listUsers,
  listAllTickets,
  updateTicketStatus,
  updateUserRole,
  updateUserStatus,
  banUser,
  unbanUser,
  promoteUser,
  demoteUser,
  logAdminAction,
  getAuditLog,
  listMatches,
  getMatchById,
  getMatchEvents,
  cancelMatch,
  listWallets,
  listWalletTransactions,
  getAdminReport,
  listSettings,
  updateSetting,
  MATCH_STATUSES,
}));

vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import {
  getStatsHandler,
  listUsersHandler,
  getUserHandler,
  updateUserStatusHandler,
  updateUserRoleHandler,
  listTicketsHandler,
  updateTicketStatusHandler,
  banUserHandler,
  unbanUserHandler,
  promoteUserHandler,
  demoteUserHandler,
  getAuditLogHandler,
  listMatchesHandler,
  getMatchHandler,
  getMatchEventsHandler,
  cancelMatchHandler,
  listWalletsHandler,
  listWalletTransactionsHandler,
  getReportHandler,
  listSettingsHandler,
  updateSettingHandler,
} from "./admin.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const VALID_UUID = "550e8400-e29b-41d4-a716-446655440000";
const ADMIN_UUID = "660e8400-e29b-41d4-a716-446655440001";

function makeReq({
  adminId = ADMIN_UUID,
  query = {} as Record<string, string>,
  body = {} as Record<string, unknown>,
  params = {} as Record<string, string>,
} = {}): Request {
  return {
    log: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
    user: { id: adminId },
    query,
    body,
    params,
  } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

function makeUser(overrides = {}) {
  return {
    id: VALID_UUID,
    player_id: "LUD-001",
    full_name: "Alice Test",
    email: "alice@example.com",
    status: "active",
    role: "player",
    ...overrides,
  };
}

function makePage<T>(rows: T[], total = rows.length) {
  return { rows, total };
}

beforeEach(() => {
  vi.resetAllMocks();
  logAdminAction.mockResolvedValue(undefined);
});

// ---------------------------------------------------------------------------
// getStatsHandler
// ---------------------------------------------------------------------------

describe("getStatsHandler", () => {
  it("returns 200 with dashboard stats", async () => {
    const stats = { total_users: 100, active_matches: 5 };
    getDashboardStats.mockResolvedValue(stats);

    const res = makeRes();
    await getStatsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { stats } });
  });

  it("returns 500 on unexpected error", async () => {
    getDashboardStats.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getStatsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// listUsersHandler
// ---------------------------------------------------------------------------

describe("listUsersHandler", () => {
  it("returns 200 with paginated users using default params", async () => {
    const user = makeUser();
    listUsers.mockResolvedValue(makePage([user]));

    const res = makeRes();
    await listUsersHandler(makeReq(), res);

    expect(listUsers).toHaveBeenCalledWith(20, 0, undefined, undefined, undefined);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        users: [user],
        pagination: { total: 1, limit: 20, offset: 0 },
      },
    });
  });

  it("forwards status, role, and search filters to the service", async () => {
    listUsers.mockResolvedValue(makePage([]));

    await listUsersHandler(
      makeReq({ query: { status: "active", role: "player", search: "alice" } }),
      makeRes(),
    );

    expect(listUsers).toHaveBeenCalledWith(20, 0, "active", "player", "alice");
  });

  it("returns 400 when limit is below minimum", async () => {
    const res = makeRes();
    await listUsersHandler(makeReq({ query: { limit: "0" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(listUsers).not.toHaveBeenCalled();
  });

  it("returns 400 when limit exceeds maximum", async () => {
    const res = makeRes();
    await listUsersHandler(makeReq({ query: { limit: "101" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(listUsers).not.toHaveBeenCalled();
  });

  it("returns 400 when status filter is invalid", async () => {
    const res = makeRes();
    await listUsersHandler(makeReq({ query: { status: "deleted" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(listUsers).not.toHaveBeenCalled();
  });

  it("returns 400 when role filter is invalid", async () => {
    const res = makeRes();
    await listUsersHandler(makeReq({ query: { role: "superuser" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(listUsers).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error", async () => {
    listUsers.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await listUsersHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// getUserHandler
// ---------------------------------------------------------------------------

describe("getUserHandler", () => {
  it("returns 200 with user when found", async () => {
    const user = makeUser();
    getUserById.mockResolvedValue(user);

    const res = makeRes();
    await getUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { user } });
  });

  it("returns 400 when id is not a valid UUID", async () => {
    const res = makeRes();
    await getUserHandler(makeReq({ params: { id: "not-a-uuid" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getUserById).not.toHaveBeenCalled();
  });

  it("returns 404 when user is not found", async () => {
    getUserById.mockResolvedValue(null);

    const res = makeRes();
    await getUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "User not found." });
  });

  it("returns 500 on unexpected error", async () => {
    getUserById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// updateUserStatusHandler
// ---------------------------------------------------------------------------

describe("updateUserStatusHandler", () => {
  it("returns 200 with updated user on success", async () => {
    const user = makeUser({ status: "suspended" });
    getUserById.mockResolvedValue(makeUser());
    updateUserStatus.mockResolvedValue(user);

    const res = makeRes();
    await updateUserStatusHandler(
      makeReq({ params: { id: VALID_UUID }, body: { status: "suspended" } }),
      res,
    );

    expect(updateUserStatus).toHaveBeenCalledWith(VALID_UUID, "suspended");
    expect(logAdminAction).toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when id is not a valid UUID", async () => {
    const res = makeRes();
    await updateUserStatusHandler(
      makeReq({ params: { id: "bad" }, body: { status: "active" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("returns 400 when status is invalid", async () => {
    const res = makeRes();
    await updateUserStatusHandler(
      makeReq({ params: { id: VALID_UUID }, body: { status: "deleted" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateUserStatus).not.toHaveBeenCalled();
  });

  it("returns 400 when admin tries to change their own status to non-active", async () => {
    const res = makeRes();
    await updateUserStatusHandler(
      makeReq({ adminId: VALID_UUID, params: { id: VALID_UUID }, body: { status: "suspended" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "You cannot change your own status.",
    });
  });

  it("returns 404 when user is not found", async () => {
    getUserById.mockResolvedValue(null);

    const res = makeRes();
    await updateUserStatusHandler(
      makeReq({ params: { id: VALID_UUID }, body: { status: "active" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
  });

  it("returns 500 on unexpected error", async () => {
    getUserById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await updateUserStatusHandler(
      makeReq({ params: { id: VALID_UUID }, body: { status: "active" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// updateUserRoleHandler
// ---------------------------------------------------------------------------

describe("updateUserRoleHandler", () => {
  it("returns 200 with updated user on success", async () => {
    const user = makeUser({ role: "admin" });
    getUserById.mockResolvedValue(makeUser());
    updateUserRole.mockResolvedValue(user);

    const res = makeRes();
    await updateUserRoleHandler(
      makeReq({ params: { id: VALID_UUID }, body: { role: "admin" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(200);
    expect(logAdminAction).toHaveBeenCalled();
  });

  it("returns 400 when role is invalid", async () => {
    const res = makeRes();
    await updateUserRoleHandler(
      makeReq({ params: { id: VALID_UUID }, body: { role: "superadmin" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateUserRole).not.toHaveBeenCalled();
  });

  it("returns 400 when admin tries to demote themselves", async () => {
    const res = makeRes();
    await updateUserRoleHandler(
      makeReq({ adminId: VALID_UUID, params: { id: VALID_UUID }, body: { role: "player" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "You cannot change your own role.",
    });
  });

  it("returns 404 when user is not found", async () => {
    getUserById.mockResolvedValue(null);

    const res = makeRes();
    await updateUserRoleHandler(
      makeReq({ params: { id: VALID_UUID }, body: { role: "admin" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
  });
});

// ---------------------------------------------------------------------------
// listTicketsHandler
// ---------------------------------------------------------------------------

describe("listTicketsHandler", () => {
  it("returns 200 with paginated tickets", async () => {
    listAllTickets.mockResolvedValue(makePage([]));

    const res = makeRes();
    await listTicketsHandler(makeReq(), res);

    expect(listAllTickets).toHaveBeenCalledWith(20, 0, undefined);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("forwards valid status filter", async () => {
    listAllTickets.mockResolvedValue(makePage([]));

    await listTicketsHandler(makeReq({ query: { status: "open" } }), makeRes());

    expect(listAllTickets).toHaveBeenCalledWith(20, 0, "open");
  });

  it("returns 400 when status filter is invalid", async () => {
    const res = makeRes();
    await listTicketsHandler(makeReq({ query: { status: "pending" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(listAllTickets).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error", async () => {
    listAllTickets.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await listTicketsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// updateTicketStatusHandler
// ---------------------------------------------------------------------------

describe("updateTicketStatusHandler", () => {
  it("returns 200 with updated ticket on success", async () => {
    const ticket = { id: VALID_UUID, user_id: "user-1", player_id: "LUD-001", status: "resolved" };
    updateTicketStatus.mockResolvedValue(ticket);

    const res = makeRes();
    await updateTicketStatusHandler(
      makeReq({ params: { id: VALID_UUID }, body: { status: "resolved" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(200);
    expect(logAdminAction).toHaveBeenCalled();
  });

  it("returns 400 when ticket id is not a valid UUID", async () => {
    const res = makeRes();
    await updateTicketStatusHandler(
      makeReq({ params: { id: "bad" }, body: { status: "resolved" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateTicketStatus).not.toHaveBeenCalled();
  });

  it("returns 400 when status is invalid", async () => {
    const res = makeRes();
    await updateTicketStatusHandler(
      makeReq({ params: { id: VALID_UUID }, body: { status: "pending" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateTicketStatus).not.toHaveBeenCalled();
  });

  it("returns 404 when ticket is not found", async () => {
    updateTicketStatus.mockResolvedValue(null);

    const res = makeRes();
    await updateTicketStatusHandler(
      makeReq({ params: { id: VALID_UUID }, body: { status: "resolved" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
  });
});

// ---------------------------------------------------------------------------
// banUserHandler / unbanUserHandler
// ---------------------------------------------------------------------------

describe("banUserHandler", () => {
  it("returns 200 with banned user on success", async () => {
    banUser.mockResolvedValue(makeUser({ status: "banned" }));

    const res = makeRes();
    await banUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(banUser).toHaveBeenCalledWith(ADMIN_UUID, VALID_UUID);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when admin tries to ban themselves", async () => {
    const res = makeRes();
    await banUserHandler(
      makeReq({ adminId: VALID_UUID, params: { id: VALID_UUID } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "You cannot ban yourself." });
  });

  it("returns 400 when id is not a valid UUID", async () => {
    const res = makeRes();
    await banUserHandler(makeReq({ params: { id: "bad" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("returns 404 when user is not found", async () => {
    banUser.mockResolvedValue(null);

    const res = makeRes();
    await banUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
  });

  it("returns 500 on unexpected error", async () => {
    banUser.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await banUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

describe("unbanUserHandler", () => {
  it("returns 200 with unbanned user on success", async () => {
    unbanUser.mockResolvedValue(makeUser({ status: "active" }));

    const res = makeRes();
    await unbanUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when id is not a valid UUID", async () => {
    const res = makeRes();
    await unbanUserHandler(makeReq({ params: { id: "bad" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("returns 404 when user is not found", async () => {
    unbanUser.mockResolvedValue(null);

    const res = makeRes();
    await unbanUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
  });
});

// ---------------------------------------------------------------------------
// promoteUserHandler / demoteUserHandler
// ---------------------------------------------------------------------------

describe("promoteUserHandler", () => {
  it("returns 200 with promoted user on success", async () => {
    promoteUser.mockResolvedValue(makeUser({ role: "admin" }));

    const res = makeRes();
    await promoteUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when id is not a valid UUID", async () => {
    const res = makeRes();
    await promoteUserHandler(makeReq({ params: { id: "bad" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("returns 404 when user is not found", async () => {
    promoteUser.mockResolvedValue(null);

    const res = makeRes();
    await promoteUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
  });
});

describe("demoteUserHandler", () => {
  it("returns 200 with demoted user on success", async () => {
    demoteUser.mockResolvedValue(makeUser({ role: "player" }));

    const res = makeRes();
    await demoteUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when admin tries to demote themselves", async () => {
    const res = makeRes();
    await demoteUserHandler(
      makeReq({ adminId: VALID_UUID, params: { id: VALID_UUID } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "You cannot demote yourself.",
    });
  });

  it("returns 404 when user is not found", async () => {
    demoteUser.mockResolvedValue(null);

    const res = makeRes();
    await demoteUserHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
  });
});

// ---------------------------------------------------------------------------
// getAuditLogHandler
// ---------------------------------------------------------------------------

describe("getAuditLogHandler", () => {
  it("returns 200 with paginated audit entries using defaults", async () => {
    getAuditLog.mockResolvedValue(makePage([]));

    const res = makeRes();
    await getAuditLogHandler(makeReq(), res);

    expect(getAuditLog).toHaveBeenCalledWith(20, 0, undefined, undefined, undefined);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when action filter is invalid", async () => {
    const res = makeRes();
    await getAuditLogHandler(makeReq({ query: { action: "delete" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getAuditLog).not.toHaveBeenCalled();
  });

  it("ignores admin_id / target_user_id that are not valid UUIDs", async () => {
    getAuditLog.mockResolvedValue(makePage([]));

    await getAuditLogHandler(
      makeReq({ query: { admin_id: "not-uuid", target_user_id: "also-not-uuid" } }),
      makeRes(),
    );

    expect(getAuditLog).toHaveBeenCalledWith(20, 0, undefined, undefined, undefined);
  });

  it("returns 500 on unexpected error", async () => {
    getAuditLog.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getAuditLogHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// listMatchesHandler
// ---------------------------------------------------------------------------

describe("listMatchesHandler", () => {
  it("returns 200 with paginated matches", async () => {
    listMatches.mockResolvedValue(makePage([]));

    const res = makeRes();
    await listMatchesHandler(makeReq(), res);

    expect(listMatches).toHaveBeenCalledWith(20, 0, undefined, undefined);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when status filter is not in MATCH_STATUSES", async () => {
    const res = makeRes();
    await listMatchesHandler(makeReq({ query: { status: "pending" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(listMatches).not.toHaveBeenCalled();
  });

  it("forwards valid status and search to the service", async () => {
    listMatches.mockResolvedValue(makePage([]));

    await listMatchesHandler(
      makeReq({ query: { status: "in_progress", search: "ABCD" } }),
      makeRes(),
    );

    expect(listMatches).toHaveBeenCalledWith(20, 0, "in_progress", "ABCD");
  });

  it("returns 500 on unexpected error", async () => {
    listMatches.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await listMatchesHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// getMatchHandler
// ---------------------------------------------------------------------------

describe("getMatchHandler", () => {
  it("returns 200 with match when found", async () => {
    const match = { id: VALID_UUID, room_code: "ABCD" };
    getMatchById.mockResolvedValue(match);

    const res = makeRes();
    await getMatchHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { match } });
  });

  it("returns 400 when match id is not a valid UUID", async () => {
    const res = makeRes();
    await getMatchHandler(makeReq({ params: { id: "bad" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("returns 404 when match is not found", async () => {
    getMatchById.mockResolvedValue(null);

    const res = makeRes();
    await getMatchHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
  });
});

// ---------------------------------------------------------------------------
// getMatchEventsHandler
// ---------------------------------------------------------------------------

describe("getMatchEventsHandler", () => {
  it("returns 200 with events when match is found", async () => {
    const events = [{ id: "e1", type: "move" }];
    getMatchById.mockResolvedValue({ id: VALID_UUID });
    getMatchEvents.mockResolvedValue(events);

    const res = makeRes();
    await getMatchEventsHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { events } });
  });

  it("returns 400 when match id is not a valid UUID", async () => {
    const res = makeRes();
    await getMatchEventsHandler(makeReq({ params: { id: "bad" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("returns 404 when match is not found", async () => {
    getMatchById.mockResolvedValue(null);

    const res = makeRes();
    await getMatchEventsHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
  });
});

// ---------------------------------------------------------------------------
// cancelMatchHandler
// ---------------------------------------------------------------------------

describe("cancelMatchHandler", () => {
  it("returns 200 with cancelled match on success", async () => {
    const match = { id: VALID_UUID, status: "cancelled" };
    cancelMatch.mockResolvedValue(match);

    const res = makeRes();
    await cancelMatchHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(cancelMatch).toHaveBeenCalledWith(ADMIN_UUID, VALID_UUID);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when match id is not a valid UUID", async () => {
    const res = makeRes();
    await cancelMatchHandler(makeReq({ params: { id: "bad" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("returns 404 when match is not found", async () => {
    cancelMatch.mockResolvedValue(null);

    const res = makeRes();
    await cancelMatchHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
  });

  it("returns 409 when match cannot be cancelled (already finished)", async () => {
    cancelMatch.mockRejectedValue(new Error("Match cannot be cancelled: already finished"));

    const res = makeRes();
    await cancelMatchHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false }),
    );
  });

  it("returns 500 on unexpected error", async () => {
    cancelMatch.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await cancelMatchHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// listWalletsHandler
// ---------------------------------------------------------------------------

describe("listWalletsHandler", () => {
  it("returns 200 with paginated wallets", async () => {
    listWallets.mockResolvedValue(makePage([]));

    const res = makeRes();
    await listWalletsHandler(makeReq(), res);

    expect(listWallets).toHaveBeenCalledWith(20, 0, undefined);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("forwards search param to the service", async () => {
    listWallets.mockResolvedValue(makePage([]));

    await listWalletsHandler(makeReq({ query: { search: "alice" } }), makeRes());

    expect(listWallets).toHaveBeenCalledWith(20, 0, "alice");
  });

  it("returns 500 on unexpected error", async () => {
    listWallets.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await listWalletsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// listWalletTransactionsHandler
// ---------------------------------------------------------------------------

describe("listWalletTransactionsHandler", () => {
  it("returns 200 with paginated transactions", async () => {
    listWalletTransactions.mockResolvedValue(makePage([]));

    const res = makeRes();
    await listWalletTransactionsHandler(makeReq({ params: { userId: VALID_UUID } }), res);

    expect(listWalletTransactions).toHaveBeenCalledWith(VALID_UUID, 20, 0);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 400 when userId is not a valid UUID", async () => {
    const res = makeRes();
    await listWalletTransactionsHandler(makeReq({ params: { userId: "bad" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(listWalletTransactions).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error", async () => {
    listWalletTransactions.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await listWalletTransactionsHandler(makeReq({ params: { userId: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// getReportHandler
// ---------------------------------------------------------------------------

describe("getReportHandler", () => {
  it("returns 200 with report using default date range", async () => {
    const report = { total_revenue: "500.00" };
    getAdminReport.mockResolvedValue(report);

    const res = makeRes();
    await getReportHandler(makeReq(), res);

    expect(getAdminReport).toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { report } });
  });

  it("returns 400 when from date is invalid", async () => {
    const res = makeRes();
    await getReportHandler(makeReq({ query: { from: "not-a-date", to: "2026-01-31" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getAdminReport).not.toHaveBeenCalled();
  });

  it("returns 400 when from is not before to", async () => {
    const res = makeRes();
    await getReportHandler(makeReq({ query: { from: "2026-02-01", to: "2026-01-01" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getAdminReport).not.toHaveBeenCalled();
  });

  it("returns 400 when date range exceeds 366 days", async () => {
    const res = makeRes();
    await getReportHandler(makeReq({ query: { from: "2024-01-01", to: "2025-12-31" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getAdminReport).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error", async () => {
    getAdminReport.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getReportHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// listSettingsHandler
// ---------------------------------------------------------------------------

describe("listSettingsHandler", () => {
  it("returns 200 with settings list", async () => {
    const settings = [{ key: "max_players", value: "2" }];
    listSettings.mockResolvedValue(settings);

    const res = makeRes();
    await listSettingsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { settings } });
  });

  it("returns 500 on unexpected error", async () => {
    listSettings.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await listSettingsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ---------------------------------------------------------------------------
// updateSettingHandler
// ---------------------------------------------------------------------------

describe("updateSettingHandler", () => {
  it("returns 200 with updated setting on success", async () => {
    const setting = { key: "max_players", value: "4" };
    updateSetting.mockResolvedValue(setting);

    const res = makeRes();
    await updateSettingHandler(makeReq({ params: { key: "max_players" }, body: { value: "4" } }), res);

    expect(updateSetting).toHaveBeenCalledWith("max_players", "4");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: { setting } });
  });

  it("returns 400 when key is invalid (fails pattern check)", async () => {
    const res = makeRes();
    await updateSettingHandler(makeReq({ params: { key: "bad key!" }, body: { value: "4" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateSetting).not.toHaveBeenCalled();
  });

  it("returns 400 when value is not a string", async () => {
    const res = makeRes();
    await updateSettingHandler(makeReq({ params: { key: "max_players" }, body: { value: 4 } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateSetting).not.toHaveBeenCalled();
  });

  it("returns 400 when value exceeds 5000 characters", async () => {
    const res = makeRes();
    await updateSettingHandler(
      makeReq({ params: { key: "max_players" }, body: { value: "x".repeat(5001) } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(updateSetting).not.toHaveBeenCalled();
  });

  it("returns 500 on unexpected error", async () => {
    updateSetting.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await updateSettingHandler(makeReq({ params: { key: "max_players" }, body: { value: "4" } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});
