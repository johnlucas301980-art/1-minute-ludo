/**
 * Admin controllers — Phase 10.1 through 10.4.
 */

import type { Request, Response } from "express";
import {
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
  // Phase 10.3
  listMatches,
  getMatchById,
  getMatchEvents,
  cancelMatch,
  MATCH_STATUSES,
  listWallets,
  listWalletTransactions,
  getAdminReport,
  listSettings,
  updateSetting,
} from "../services/admin.service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const DEFAULT_LIMIT = 20;
const MIN_LIMIT     = 1;
const MAX_LIMIT     = 100;

const VALID_USER_STATUSES   = new Set(["active", "suspended", "banned"]);
const VALID_USER_ROLES      = new Set(["player", "admin"]);
const VALID_TICKET_STATUSES = new Set(["open", "in_progress", "resolved", "closed"]);
const VALID_AUDIT_ACTIONS   = new Set([
  "ban", "unban", "promote", "demote",
  "status_change", "role_change", "ticket_status_change",
]);
const SETTING_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$/;
const REPORT_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function parsePagination(req: Request): { limit: number; offset: number } | { error: string } {
  const rawLimit  = req.query["limit"];
  const rawOffset = req.query["offset"];

  let limit = DEFAULT_LIMIT;
  if (rawLimit !== undefined && rawLimit !== "") {
    const parsed = Number.parseInt(String(rawLimit), 10);
    if (!Number.isFinite(parsed)) {
      limit = DEFAULT_LIMIT;
    } else if (parsed < MIN_LIMIT) {
      return { error: `limit must be at least ${MIN_LIMIT}.` };
    } else if (parsed > MAX_LIMIT) {
      return { error: `limit must not exceed ${MAX_LIMIT}.` };
    } else {
      limit = parsed;
    }
  }

  let offset = 0;
  if (rawOffset !== undefined && rawOffset !== "") {
    const parsed = Number.parseInt(String(rawOffset), 10);
    offset = Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
  }

  return { limit, offset };
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}

// ---------------------------------------------------------------------------
// GET /api/admin/stats
// ---------------------------------------------------------------------------

export async function getStatsHandler(req: Request, res: Response): Promise<void> {
  try {
    const stats = await getDashboardStats();
    res.status(200).json({ success: true, data: { stats } });
  } catch (err) {
    req.log.error({ err }, "Admin.GetStats: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// GET /api/admin/users   (Phase 10.2: adds ?search= param)
// ---------------------------------------------------------------------------

export async function listUsersHandler(req: Request, res: Response): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  const rawStatus = req.query["status"];
  const rawRole   = req.query["role"];
  const rawSearch = req.query["search"];

  const status = typeof rawStatus === "string" && rawStatus !== "" ? rawStatus : undefined;
  const role   = typeof rawRole   === "string" && rawRole   !== "" ? rawRole   : undefined;
  const search = typeof rawSearch === "string" && rawSearch.trim() !== ""
    ? rawSearch.trim()
    : undefined;

  if (status && !VALID_USER_STATUSES.has(status)) {
    res.status(400).json({
      success: false,
      message: `status must be one of: ${[...VALID_USER_STATUSES].join(", ")}.`,
    });
    return;
  }
  if (role && !VALID_USER_ROLES.has(role)) {
    res.status(400).json({
      success: false,
      message: `role must be one of: ${[...VALID_USER_ROLES].join(", ")}.`,
    });
    return;
  }

  try {
    const page = await listUsers(parsed.limit, parsed.offset, status, role, search);
    res.status(200).json({
      success: true,
      data: {
        users: page.rows,
        pagination: { total: page.total, limit: parsed.limit, offset: parsed.offset },
      },
    });
  } catch (err) {
    req.log.error({ err }, "Admin.ListUsers: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// GET /api/admin/users/:id
// ---------------------------------------------------------------------------

export async function getUserHandler(req: Request, res: Response): Promise<void> {
  const rawId  = req.params["id"];
  const userId = typeof rawId === "string" ? rawId : undefined;

  if (!userId || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }

  try {
    const user = await getUserById(userId);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }
    res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.GetUser: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// PATCH /api/admin/users/:id/status  (generic — logs as status_change)
// ---------------------------------------------------------------------------

export async function updateUserStatusHandler(req: Request, res: Response): Promise<void> {
  const rawId  = req.params["id"];
  const userId = typeof rawId === "string" ? rawId : undefined;

  if (!userId || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }

  const { status } = req.body as Record<string, unknown>;
  if (typeof status !== "string" || !VALID_USER_STATUSES.has(status)) {
    res.status(400).json({
      success: false,
      message: `status must be one of: ${[...VALID_USER_STATUSES].join(", ")}.`,
    });
    return;
  }

  if (userId === req.user!.id && status !== "active") {
    res.status(400).json({ success: false, message: "You cannot change your own status." });
    return;
  }

  try {
    const current = await getUserById(userId);
    if (!current) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }

    const user = await updateUserStatus(userId, status);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }

    await logAdminAction({
      adminId: req.user!.id,
      targetUserId: userId,
      action: "status_change",
      oldValue: current.status,
      newValue: status,
      details: { player_id: current.player_id },
    });

    res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.UpdateUserStatus: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// PATCH /api/admin/users/:id/role  (generic — logs as role_change)
// ---------------------------------------------------------------------------

export async function updateUserRoleHandler(req: Request, res: Response): Promise<void> {
  const rawId  = req.params["id"];
  const userId = typeof rawId === "string" ? rawId : undefined;

  if (!userId || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }

  const { role } = req.body as Record<string, unknown>;
  if (typeof role !== "string" || !VALID_USER_ROLES.has(role)) {
    res.status(400).json({
      success: false,
      message: `role must be one of: ${[...VALID_USER_ROLES].join(", ")}.`,
    });
    return;
  }

  if (userId === req.user!.id && role !== "admin") {
    res.status(400).json({ success: false, message: "You cannot change your own role." });
    return;
  }

  try {
    const current = await getUserById(userId);
    if (!current) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }

    const user = await updateUserRole(userId, role);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }

    await logAdminAction({
      adminId: req.user!.id,
      targetUserId: userId,
      action: "role_change",
      oldValue: current.role,
      newValue: role,
      details: { player_id: current.player_id },
    });

    res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.UpdateUserRole: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// GET /api/admin/tickets
// ---------------------------------------------------------------------------

export async function listTicketsHandler(req: Request, res: Response): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  const rawStatus = req.query["status"];
  const status    = typeof rawStatus === "string" && rawStatus !== "" ? rawStatus : undefined;

  if (status && !VALID_TICKET_STATUSES.has(status)) {
    res.status(400).json({
      success: false,
      message: `status must be one of: ${[...VALID_TICKET_STATUSES].join(", ")}.`,
    });
    return;
  }

  try {
    const page = await listAllTickets(parsed.limit, parsed.offset, status);
    res.status(200).json({
      success: true,
      data: {
        tickets: page.rows,
        pagination: { total: page.total, limit: parsed.limit, offset: parsed.offset },
      },
    });
  } catch (err) {
    req.log.error({ err }, "Admin.ListTickets: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// PATCH /api/admin/tickets/:id/status  (logs as ticket_status_change)
// ---------------------------------------------------------------------------

export async function updateTicketStatusHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const rawId    = req.params["id"];
  const ticketId = typeof rawId === "string" ? rawId : undefined;

  if (!ticketId || !isUuid(ticketId)) {
    res.status(400).json({ success: false, message: "A valid ticket id is required." });
    return;
  }

  const { status } = req.body as Record<string, unknown>;
  if (typeof status !== "string" || !VALID_TICKET_STATUSES.has(status)) {
    res.status(400).json({
      success: false,
      message: `status must be one of: ${[...VALID_TICKET_STATUSES].join(", ")}.`,
    });
    return;
  }

  try {
    const ticket = await updateTicketStatus(ticketId, status);
    if (!ticket) {
      res.status(404).json({ success: false, message: "Ticket not found." });
      return;
    }

    await logAdminAction({
      adminId: req.user!.id,
      targetUserId: ticket.user_id,
      action: "ticket_status_change",
      oldValue: null,
      newValue: status,
      details: { ticket_id: ticketId, player_id: ticket.player_id },
    });

    res.status(200).json({ success: true, data: { ticket } });
  } catch (err) {
    req.log.error({ err, ticketId }, "Admin.UpdateTicketStatus: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.2 — POST /api/admin/users/:id/ban
// ---------------------------------------------------------------------------

export async function banUserHandler(req: Request, res: Response): Promise<void> {
  const rawId  = req.params["id"];
  const userId = typeof rawId === "string" ? rawId : undefined;

  if (!userId || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }
  if (userId === req.user!.id) {
    res.status(400).json({ success: false, message: "You cannot ban yourself." });
    return;
  }

  try {
    const user = await banUser(req.user!.id, userId);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }
    res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.BanUser: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.2 — POST /api/admin/users/:id/unban
// ---------------------------------------------------------------------------

export async function unbanUserHandler(req: Request, res: Response): Promise<void> {
  const rawId  = req.params["id"];
  const userId = typeof rawId === "string" ? rawId : undefined;

  if (!userId || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }

  try {
    const user = await unbanUser(req.user!.id, userId);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }
    res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.UnbanUser: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.2 — POST /api/admin/users/:id/promote
// ---------------------------------------------------------------------------

export async function promoteUserHandler(req: Request, res: Response): Promise<void> {
  const rawId  = req.params["id"];
  const userId = typeof rawId === "string" ? rawId : undefined;

  if (!userId || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }

  try {
    const user = await promoteUser(req.user!.id, userId);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }
    res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.PromoteUser: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.2 — POST /api/admin/users/:id/demote
// ---------------------------------------------------------------------------

export async function demoteUserHandler(req: Request, res: Response): Promise<void> {
  const rawId  = req.params["id"];
  const userId = typeof rawId === "string" ? rawId : undefined;

  if (!userId || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }
  if (userId === req.user!.id) {
    res.status(400).json({ success: false, message: "You cannot demote yourself." });
    return;
  }

  try {
    const user = await demoteUser(req.user!.id, userId);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }
    res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.DemoteUser: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.2 — GET /api/admin/audit-log
// ---------------------------------------------------------------------------

export async function getAuditLogHandler(req: Request, res: Response): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  const rawAdminId  = req.query["admin_id"];
  const rawTargetId = req.query["target_user_id"];
  const rawAction   = req.query["action"];

  const adminId      = typeof rawAdminId  === "string" && isUuid(rawAdminId)  ? rawAdminId  : undefined;
  const targetUserId = typeof rawTargetId === "string" && isUuid(rawTargetId) ? rawTargetId : undefined;
  const action       = typeof rawAction   === "string" && rawAction !== ""    ? rawAction   : undefined;

  if (action && !VALID_AUDIT_ACTIONS.has(action)) {
    res.status(400).json({
      success: false,
      message: `action must be one of: ${[...VALID_AUDIT_ACTIONS].join(", ")}.`,
    });
    return;
  }

  try {
    const page = await getAuditLog(parsed.limit, parsed.offset, adminId, targetUserId, action);
    res.status(200).json({
      success: true,
      data: {
        entries: page.rows,
        pagination: { total: page.total, limit: parsed.limit, offset: parsed.offset },
      },
    });
  } catch (err) {
    req.log.error({ err }, "Admin.GetAuditLog: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.3 — Match Monitoring
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// GET /api/admin/matches
// ---------------------------------------------------------------------------

export async function listMatchesHandler(req: Request, res: Response): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  const rawStatus = req.query["status"];
  const rawSearch = req.query["search"];

  const status = typeof rawStatus === "string" && rawStatus !== "" ? rawStatus : undefined;
  const search = typeof rawSearch === "string" && rawSearch.trim() !== ""
    ? rawSearch.trim()
    : undefined;

  if (status && !MATCH_STATUSES.has(status)) {
    res.status(400).json({
      success: false,
      message: `status must be one of: ${[...MATCH_STATUSES].join(", ")}.`,
    });
    return;
  }

  try {
    const page = await listMatches(parsed.limit, parsed.offset, status, search);
    res.status(200).json({
      success: true,
      data: {
        matches: page.rows,
        pagination: { total: page.total, limit: parsed.limit, offset: parsed.offset },
      },
    });
  } catch (err) {
    req.log.error({ err }, "Admin.ListMatches: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// GET /api/admin/matches/:id
// ---------------------------------------------------------------------------

export async function getMatchHandler(req: Request, res: Response): Promise<void> {
  const { id } = req.params as { id: string };
  if (!isUuid(id)) {
    res.status(400).json({ success: false, message: "Invalid match ID." });
    return;
  }

  try {
    const match = await getMatchById(id);
    if (!match) {
      res.status(404).json({ success: false, message: "Match not found." });
      return;
    }
    res.status(200).json({ success: true, data: { match } });
  } catch (err) {
    req.log.error({ err }, "Admin.GetMatch: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// GET /api/admin/matches/:id/events
// ---------------------------------------------------------------------------

export async function getMatchEventsHandler(req: Request, res: Response): Promise<void> {
  const { id } = req.params as { id: string };
  if (!isUuid(id)) {
    res.status(400).json({ success: false, message: "Invalid match ID." });
    return;
  }

  try {
    const match = await getMatchById(id);
    if (!match) {
      res.status(404).json({ success: false, message: "Match not found." });
      return;
    }
    const events = await getMatchEvents(id);
    res.status(200).json({ success: true, data: { events } });
  } catch (err) {
    req.log.error({ err }, "Admin.GetMatchEvents: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// POST /api/admin/matches/:id/cancel
// ---------------------------------------------------------------------------

export async function cancelMatchHandler(req: Request, res: Response): Promise<void> {
  const { id } = req.params as { id: string };
  if (!isUuid(id)) {
    res.status(400).json({ success: false, message: "Invalid match ID." });
    return;
  }

  const adminId = (req as Request & { user?: { id: string } }).user?.id;
  if (!adminId) {
    res.status(401).json({ success: false, message: "Unauthorized." });
    return;
  }

  try {
    const match = await cancelMatch(adminId, id);
    if (!match) {
      res.status(404).json({ success: false, message: "Match not found." });
      return;
    }
    res.status(200).json({ success: true, data: { match } });
  } catch (err) {
    if (err instanceof Error && err.message.startsWith("Match cannot be cancelled")) {
      res.status(409).json({ success: false, message: err.message });
      return;
    }
    req.log.error({ err }, "Admin.CancelMatch: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.4 — Wallet monitoring
// ---------------------------------------------------------------------------

export async function listWalletsHandler(req: Request, res: Response): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  const rawSearch = req.query["search"];
  const search = typeof rawSearch === "string" && rawSearch.trim() !== ""
    ? rawSearch.trim()
    : undefined;

  try {
    const page = await listWallets(parsed.limit, parsed.offset, search);
    res.status(200).json({
      success: true,
      data: {
        wallets: page.rows,
        pagination: { total: page.total, limit: parsed.limit, offset: parsed.offset },
      },
    });
  } catch (err) {
    req.log.error({ err }, "Admin.ListWallets: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

export async function listWalletTransactionsHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  const userId = req.params["userId"];
  if (typeof userId !== "string" || !isUuid(userId)) {
    res.status(400).json({ success: false, message: "A valid user id is required." });
    return;
  }

  try {
    const page = await listWalletTransactions(userId, parsed.limit, parsed.offset);
    res.status(200).json({
      success: true,
      data: {
        transactions: page.rows,
        pagination: { total: page.total, limit: parsed.limit, offset: parsed.offset },
      },
    });
  } catch (err) {
    req.log.error({ err, userId }, "Admin.ListWalletTransactions: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.4 — Reports
// ---------------------------------------------------------------------------

function parseReportDate(value: unknown): Date | null {
  if (typeof value !== "string" || !REPORT_DATE_PATTERN.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

export async function getReportHandler(req: Request, res: Response): Promise<void> {
  const now = new Date();
  const defaultFrom = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1_000);
  const from = req.query["from"] === undefined
    ? defaultFrom
    : parseReportDate(req.query["from"]);
  const requestedTo = req.query["to"] === undefined
    ? now
    : parseReportDate(req.query["to"]);

  if (!from || !requestedTo) {
    res.status(400).json({
      success: false,
      message: "from and to must be valid dates in YYYY-MM-DD format.",
    });
    return;
  }

  const to = req.query["to"] === undefined
    ? requestedTo
    : new Date(requestedTo.getTime() + 24 * 60 * 60 * 1_000);

  if (from >= to) {
    res.status(400).json({ success: false, message: "from must be before to." });
    return;
  }

  const maxRangeMs = 366 * 24 * 60 * 60 * 1_000;
  if (to.getTime() - from.getTime() > maxRangeMs) {
    res.status(400).json({ success: false, message: "Report range must not exceed 366 days." });
    return;
  }

  try {
    const report = await getAdminReport(from, to);
    res.status(200).json({ success: true, data: { report } });
  } catch (err) {
    req.log.error({ err }, "Admin.GetReport: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Phase 10.4 — Settings
// ---------------------------------------------------------------------------

export async function listSettingsHandler(req: Request, res: Response): Promise<void> {
  try {
    const settings = await listSettings();
    res.status(200).json({ success: true, data: { settings } });
  } catch (err) {
    req.log.error({ err }, "Admin.ListSettings: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

export async function updateSettingHandler(req: Request, res: Response): Promise<void> {
  const key = req.params["key"];
  const value = (req.body as Record<string, unknown>)["value"];

  if (typeof key !== "string" || !SETTING_KEY_PATTERN.test(key)) {
    res.status(400).json({ success: false, message: "A valid setting key is required." });
    return;
  }
  if (typeof value !== "string" || value.length > 5_000) {
    res.status(400).json({
      success: false,
      message: "Setting value must be a string of at most 5000 characters.",
    });
    return;
  }

  try {
    const setting = await updateSetting(key, value);
    res.status(200).json({ success: true, data: { setting } });
  } catch (err) {
    req.log.error({ err, key }, "Admin.UpdateSetting: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
