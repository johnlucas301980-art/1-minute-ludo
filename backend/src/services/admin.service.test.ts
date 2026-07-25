import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import {
  CANCELLABLE_STATUSES,
  MATCH_STATUSES,
  banUser,
  cancelMatch,
  demoteUser,
  getAdminReport,
  getAuditLog,
  getDashboardStats,
  getMatchById,
  getMatchEvents,
  getUserById,
  listAllTickets,
  listMatches,
  listSettings,
  listUsers,
  listWalletTransactions,
  listWallets,
  logAdminAction,
  promoteUser,
  unbanUser,
  updateSetting,
  updateTicketStatus,
  updateUserRole,
  updateUserStatus,
  type AdminMatchRow,
  type AdminSettingRow,
  type AdminTicketRow,
  type AdminUserRow,
  type AdminWalletRow,
} from "./admin.service.js";

function makeUser(overrides: Partial<AdminUserRow> = {}): AdminUserRow {
  return {
    id: "user-1",
    player_id: "LUD-000001",
    full_name: "Alice",
    email: "alice@example.com",
    mobile: "+1234567890",
    role: "player",
    status: "active",
    is_verified: true,
    country: "US",
    last_login_at: new Date("2026-01-02T00:00:00Z"),
    created_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

function makeTicket(overrides: Partial<AdminTicketRow> = {}): AdminTicketRow {
  return {
    id: "ticket-1",
    user_id: "user-1",
    player_id: "LUD-000001",
    full_name: "Alice",
    subject: "Help",
    message: "Please help",
    status: "open",
    created_at: new Date("2026-01-01T00:00:00Z"),
    updated_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

function makeMatch(overrides: Partial<AdminMatchRow> = {}): AdminMatchRow {
  return {
    id: "match-1",
    room_code: "ABC123",
    mode: "random",
    status: "waiting",
    entry_points: "10.00",
    player_count: 2,
    winner_id: null,
    winner_player_id: null,
    winner_full_name: null,
    started_at: null,
    finished_at: null,
    created_at: new Date("2026-01-01T00:00:00Z"),
    players: [],
    ...overrides,
  };
}

function makeWallet(overrides: Partial<AdminWalletRow> = {}): AdminWalletRow {
  return {
    wallet_id: "wallet-1",
    user_id: "user-1",
    player_id: "LUD-000001",
    full_name: "Alice",
    user_status: "active",
    points: "100.00",
    total_deposit: "120.00",
    total_withdraw: "20.00",
    transaction_count: 3,
    last_transaction_at: new Date("2026-01-03T00:00:00Z"),
    updated_at: new Date("2026-01-03T00:00:00Z"),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

describe("admin constants", () => {
  it("keeps the match status sets aligned with the supported lifecycle", () => {
    expect([...MATCH_STATUSES]).toEqual([
      "waiting",
      "in_progress",
      "finished",
      "cancelled",
    ]);
    expect([...CANCELLABLE_STATUSES]).toEqual(["waiting", "in_progress"]);
  });
});

describe("getDashboardStats", () => {
  it("returns the aggregate dashboard row", async () => {
    const stats = {
      total_users: 10,
      active_users: 8,
      suspended_users: 1,
      banned_users: 1,
      admin_users: 2,
      total_matches: 20,
      in_progress_matches: 3,
      total_wallet_balance: 400,
      open_tickets: 4,
      in_progress_tickets: 2,
    };
    pool.query.mockResolvedValue({ rows: [stats] });

    await expect(getDashboardStats()).resolves.toEqual(stats);

    expect(pool.query).toHaveBeenCalledOnce();
    expect(pool.query.mock.calls[0][0]).toMatch(/FROM users/i);
    expect(pool.query.mock.calls[0][0]).toMatch(/FROM support_tickets/i);
  });

  it("propagates a dashboard query error", async () => {
    pool.query.mockRejectedValue(new Error("dashboard failed"));

    await expect(getDashboardStats()).rejects.toThrow("dashboard failed");
  });
});

describe("user management", () => {
  it("lists users with pagination and no filters", async () => {
    const rows = [makeUser()];
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows });

    await expect(listUsers(20, 5)).resolves.toEqual({ rows, total: 1 });

    expect(pool.query.mock.calls[0][1]).toEqual([]);
    expect(pool.query.mock.calls[1][1]).toEqual([20, 5]);
    expect(pool.query.mock.calls[1][0]).toMatch(
      /ORDER BY created_at DESC, id DESC/i,
    );
  });

  it("combines status, role, and search filters in parameter order", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "2" }] })
      .mockResolvedValueOnce({ rows: [] });

    await listUsers(10, 2, "active", "admin", "Alice");

    const [countSql, countParams] = pool.query.mock.calls[0];
    const [rowsSql, rowsParams] = pool.query.mock.calls[1];
    expect(countSql).toMatch(/status = \$1.*role = \$2/is);
    expect(countSql).toMatch(/full_name ILIKE \$3/i);
    expect(countParams).toEqual(["active", "admin", "%Alice%"]);
    expect(rowsSql).toMatch(/LIMIT \$4 OFFSET \$5/i);
    expect(rowsParams).toEqual(["active", "admin", "%Alice%", 10, 2]);
  });

  it("defaults a missing count row to zero", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    await expect(listUsers(20, 0)).resolves.toEqual({ rows: [], total: 0 });
  });

  it("gets a user or returns null when absent", async () => {
    pool.query.mockResolvedValueOnce({ rows: [makeUser()] });
    await expect(getUserById("user-1")).resolves.toEqual(makeUser());
    expect(pool.query.mock.calls[0][1]).toEqual(["user-1"]);

    pool.query.mockResolvedValueOnce({ rows: [] });
    await expect(getUserById("missing")).resolves.toBeNull();
  });

  it("updates user status and role with the target id", async () => {
    const suspended = makeUser({ status: "suspended" });
    const admin = makeUser({ role: "admin" });
    pool.query
      .mockResolvedValueOnce({ rows: [suspended] })
      .mockResolvedValueOnce({ rows: [admin] });

    await expect(updateUserStatus("user-1", "suspended")).resolves.toEqual(
      suspended,
    );
    await expect(updateUserRole("user-1", "admin")).resolves.toEqual(admin);
    expect(pool.query.mock.calls[0][1]).toEqual(["suspended", "user-1"]);
    expect(pool.query.mock.calls[1][1]).toEqual(["admin", "user-1"]);
  });
});

describe("ticket management", () => {
  it("lists all tickets and supports a status filter", async () => {
    const ticket = makeTicket();
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [ticket] });

    await expect(listAllTickets(10, 4)).resolves.toEqual({
      rows: [ticket],
      total: 1,
    });
    expect(pool.query.mock.calls[1][1]).toEqual([10, 4]);

    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [ticket] });
    await listAllTickets(10, 4, "open");
    expect(pool.query.mock.calls[2][1]).toEqual(["open"]);
    expect(pool.query.mock.calls[3][1]).toEqual(["open", 10, 4]);
  });

  it("updates a ticket and enriches the returned user fields", async () => {
    const ticket = makeTicket({ player_id: "", full_name: "" });
    pool.query
      .mockResolvedValueOnce({ rows: [ticket] })
      .mockResolvedValueOnce({
        rows: [{ player_id: "LUD-000001", full_name: "Alice" }],
      });

    await expect(updateTicketStatus("ticket-1", "resolved")).resolves.toEqual(
      makeTicket({
        status: "open",
        player_id: "LUD-000001",
        full_name: "Alice",
      }),
    );
    expect(pool.query.mock.calls[0][1]).toEqual(["resolved", "ticket-1"]);
    expect(pool.query.mock.calls[1][1]).toEqual(["user-1"]);
  });

  it("returns null without a user lookup when the ticket is missing", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(updateTicketStatus("missing", "closed")).resolves.toBeNull();
    expect(pool.query).toHaveBeenCalledOnce();
  });
});

describe("audit log and user actions", () => {
  it("serializes optional audit values and details", async () => {
    pool.query.mockResolvedValue({});

    await logAdminAction({
      adminId: "admin-1",
      targetUserId: undefined,
      action: "ban",
      oldValue: "active",
      newValue: "banned",
      details: { reason: "fraud" },
    });

    expect(pool.query.mock.calls[0][1]).toEqual([
      "admin-1",
      null,
      "ban",
      "active",
      "banned",
      JSON.stringify({ reason: "fraud" }),
    ]);
  });

  it("gets a paginated audit log with all filters", async () => {
    const row = {
      id: "audit-1",
      admin_id: "admin-1",
      admin_player_id: "LUD-ADMIN",
      admin_full_name: "Admin",
      target_user_id: "user-1",
      target_player_id: "LUD-000001",
      target_full_name: "Alice",
      action: "ban",
      old_value: "active",
      new_value: "banned",
      details: null,
      created_at: new Date("2026-01-01T00:00:00Z"),
    };
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [row] });

    await expect(
      getAuditLog(10, 2, "admin-1", "user-1", "ban"),
    ).resolves.toEqual({
      rows: [row],
      total: 1,
    });
    expect(pool.query.mock.calls[0][1]).toEqual(["admin-1", "user-1", "ban"]);
    expect(pool.query.mock.calls[1][1]).toEqual([
      "admin-1",
      "user-1",
      "ban",
      10,
      2,
    ]);
  });

  it.each([
    ["ban", "active", "banned", banUser],
    ["unban", "banned", "active", unbanUser],
    ["promote", "player", "admin", promoteUser],
    ["demote", "admin", "player", demoteUser],
  ] as const)(
    "performs the %s action, updates the user, and writes an audit record",
    async (action, oldValue, newValue, actionFn) => {
      const current = makeUser({
        status: action === "unban" ? "banned" : "active",
        role: oldValue === "admin" ? "admin" : "player",
      });
      const updated = makeUser({
        status: newValue === "banned" ? "banned" : "active",
        role: newValue === "admin" ? "admin" : "player",
      });
      pool.query
        .mockResolvedValueOnce({ rows: [current] })
        .mockResolvedValueOnce({ rows: [updated] })
        .mockResolvedValueOnce({});

      await expect(actionFn("admin-1", "user-1")).resolves.toEqual(updated);
      expect(pool.query.mock.calls[2][1]).toEqual([
        "admin-1",
        "user-1",
        action,
        oldValue,
        newValue,
        JSON.stringify({ player_id: "LUD-000001" }),
      ]);
    },
  );

  it("does not update or audit a missing target user", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(banUser("admin-1", "missing")).resolves.toBeNull();
    expect(pool.query).toHaveBeenCalledOnce();
  });
});

describe("match monitoring", () => {
  it("lists matches with parsed JSON players and total", async () => {
    const players = [
      {
        user_id: "user-1",
        player_id: "LUD-000001",
        full_name: "Alice",
        color: "blue",
        final_rank: null,
      },
    ];
    const raw = { ...makeMatch(), players: JSON.stringify(players) };
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [raw] });

    await expect(listMatches(20, 3)).resolves.toEqual({
      rows: [{ ...makeMatch(), players }],
      total: 1,
    });
    expect(pool.query.mock.calls[0][1]).toEqual([]);
    expect(pool.query.mock.calls[1][1]).toEqual([20, 3]);
  });

  it("applies status and search filters to match queries", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "0" }] })
      .mockResolvedValueOnce({ rows: [] });

    await listMatches(10, 1, "in_progress", "Alice");

    expect(pool.query.mock.calls[0][1]).toEqual(["in_progress", "%Alice%"]);
    expect(pool.query.mock.calls[0][0]).toMatch(/m\.status = \$1/i);
    expect(pool.query.mock.calls[1][1]).toEqual([
      "in_progress",
      "%Alice%",
      10,
      1,
    ]);
    expect(pool.query.mock.calls[1][0]).toMatch(/LIMIT \$3 OFFSET \$4/i);
  });

  it("gets a match by id and parses an already-decoded player array", async () => {
    const match = makeMatch({
      players: [
        {
          user_id: "user-1",
          player_id: "LUD-000001",
          full_name: "Alice",
          color: "blue",
          final_rank: 1,
        },
      ],
    });
    pool.query.mockResolvedValue({ rows: [match] });

    await expect(getMatchById("match-1")).resolves.toEqual(match);
    expect(pool.query.mock.calls[0][1]).toEqual(["match-1"]);
  });

  it("returns null for an unknown match", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(getMatchById("missing")).resolves.toBeNull();
  });

  it("builds and chronologically sorts match events", async () => {
    const created = new Date("2026-01-01T00:00:00Z");
    const joined = new Date("2026-01-01T00:00:02Z");
    const started = new Date("2026-01-01T00:00:03Z");
    const finished = new Date("2026-01-01T00:00:04Z");
    pool.query.mockResolvedValue({
      rows: [
        {
          id: "match-1",
          room_code: "ABC123",
          status: "finished",
          created_at: created,
          started_at: started,
          finished_at: finished,
          user_id: "user-1",
          player_id: "LUD-000001",
          full_name: "Alice",
          color: "blue",
          joined_at: joined,
        },
      ],
    });

    await expect(getMatchEvents("match-1")).resolves.toEqual([
      {
        type: "match_created",
        description: "Match ABC123 created.",
        timestamp: created,
        meta: { room_code: "ABC123" },
      },
      {
        type: "player_joined",
        description: "Alice (LUD-000001) joined as blue.",
        timestamp: joined,
        meta: { user_id: "user-1", player_id: "LUD-000001", color: "blue" },
      },
      {
        type: "match_started",
        description: "Match started.",
        timestamp: started,
      },
      {
        type: "match_finished",
        description: "Match finished.",
        timestamp: finished,
      },
    ]);
  });

  it("returns no events for an unknown match", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(getMatchEvents("missing")).resolves.toEqual([]);
  });

  it("cancels a cancellable match and records the prior status", async () => {
    const existing = makeMatch({ status: "in_progress" });
    const updated = makeMatch({
      status: "cancelled",
      finished_at: new Date("2026-01-02T00:00:00Z"),
    });
    pool.query
      .mockResolvedValueOnce({ rows: [existing] })
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({ rows: [updated] });

    await expect(cancelMatch("admin-1", "match-1")).resolves.toEqual(updated);
    expect(pool.query.mock.calls[0][1]).toEqual(["match-1"]);
    expect(pool.query.mock.calls[1][1][1]).toBe("match-1");
    expect(pool.query.mock.calls[1][1][2]).toEqual(["waiting", "in_progress"]);
    expect(pool.query.mock.calls[2][1]).toEqual([
      "admin-1",
      null,
      "match_cancel",
      "in_progress",
      "cancelled",
      JSON.stringify({ match_id: "match-1", room_code: "ABC123" }),
    ]);
    expect(pool.query.mock.calls[3][1]).toEqual(["match-1"]);
  });

  it("rejects cancellation of a terminal match and skips writes", async () => {
    pool.query.mockResolvedValue({ rows: [makeMatch({ status: "finished" })] });

    await expect(cancelMatch("admin-1", "match-1")).rejects.toThrow(
      "Match cannot be cancelled: current status is 'finished'.",
    );
    expect(pool.query).toHaveBeenCalledOnce();
  });
});

describe("wallet monitoring", () => {
  it("lists wallets with optional search and pagination", async () => {
    const wallet = makeWallet();
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [wallet] });

    await expect(listWallets(10, 2)).resolves.toEqual({
      rows: [wallet],
      total: 1,
    });
    expect(pool.query.mock.calls[1][1]).toEqual([10, 2]);

    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [wallet] });
    await listWallets(10, 2, "Alice");
    expect(pool.query.mock.calls[2][1]).toEqual(["%Alice%"]);
    expect(pool.query.mock.calls[3][1]).toEqual(["%Alice%", 10, 2]);
  });

  it("lists a user's transactions and converts a missing count to zero", async () => {
    const transaction = {
      id: "transaction-1",
      user_id: "user-1",
      player_id: "LUD-000001",
      full_name: "Alice",
      type: "deposit",
      amount: "10.00",
      status: "completed",
      reference: null,
      created_at: new Date("2026-01-01T00:00:00Z"),
    };
    pool.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [transaction] });

    await expect(listWalletTransactions("user-1", 10, 2)).resolves.toEqual({
      rows: [transaction],
      total: 0,
    });
    expect(pool.query.mock.calls[0][1]).toEqual(["user-1"]);
    expect(pool.query.mock.calls[1][1]).toEqual(["user-1", 10, 2]);
  });
});

describe("reports and settings", () => {
  it("combines report queries and converts count values to numbers", async () => {
    const from = new Date("2026-01-01T00:00:00Z");
    const to = new Date("2026-02-01T00:00:00Z");
    pool.query
      .mockResolvedValueOnce({
        rows: [
          {
            total: "10",
            new_users: "3",
            active: "8",
            suspended: "1",
            banned: "1",
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [
          {
            total: "5",
            waiting: "1",
            in_progress: "2",
            finished: "1",
            cancelled: "1",
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [
          {
            wallet_count: "4",
            total_points: "100.50",
            total_deposit: "120.00",
            total_withdraw: "19.50",
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [
          {
            total: "6",
            deposit: "20.00",
            withdraw: "5.00",
            reward: "3.00",
            entry_fee: "10.00",
            refund: "2.00",
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [{ open: "1", in_progress: "2", resolved: "3", closed: "4" }],
      });

    await expect(getAdminReport(from, to)).resolves.toEqual({
      from,
      to,
      users: { total: 10, new_users: 3, active: 8, suspended: 1, banned: 1 },
      matches: {
        total: 5,
        waiting: 1,
        in_progress: 2,
        finished: 1,
        cancelled: 1,
      },
      wallets: {
        wallet_count: 4,
        total_points: "100.50",
        total_deposit: "120.00",
        total_withdraw: "19.50",
      },
      transactions: {
        total: 6,
        deposit: "20.00",
        withdraw: "5.00",
        reward: "3.00",
        entry_fee: "10.00",
        refund: "2.00",
      },
      support: { open: 1, in_progress: 2, resolved: 3, closed: 4 },
    });
    expect(pool.query.mock.calls[0][1]).toEqual([from, to]);
    expect(pool.query.mock.calls[2][1]).toBeUndefined();
  });

  it("lists settings in key order and upserts a setting", async () => {
    const setting: AdminSettingRow = {
      id: "setting-1",
      key: "match_duration",
      value: "60",
      updated_at: new Date("2026-01-01T00:00:00Z"),
    };
    pool.query
      .mockResolvedValueOnce({ rows: [setting] })
      .mockResolvedValueOnce({ rows: [setting] });

    await expect(listSettings()).resolves.toEqual([setting]);
    await expect(updateSetting("match_duration", "60")).resolves.toEqual(
      setting,
    );
    expect(pool.query.mock.calls[0][0]).toMatch(
      /FROM settings.*ORDER BY key ASC/is,
    );
    expect(pool.query.mock.calls[1][1]).toEqual(["match_duration", "60"]);
    expect(pool.query.mock.calls[1][0]).toMatch(
      /ON CONFLICT \(key\) DO UPDATE/i,
    );
  });

  it("propagates report and settings database errors", async () => {
    pool.query.mockRejectedValue(new Error("report failed"));
    await expect(getAdminReport(new Date(), new Date())).rejects.toThrow(
      "report failed",
    );

    pool.query.mockRejectedValue(new Error("settings failed"));
    await expect(listSettings()).rejects.toThrow("settings failed");
  });
});
