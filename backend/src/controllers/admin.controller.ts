/**
 * Admin controllers — Phase 10.1.
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
} from "../services/admin.service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const DEFAULT_LIMIT = 20;
const MIN_LIMIT     = 1;
const MAX_LIMIT     = 100;

const VALID_USER_STATUSES = new Set(["active", "suspended", "banned"]);
const VALID_USER_ROLES    = new Set(["player", "admin"]);
const VALID_TICKET_STATUSES = new Set(["open", "in_progress", "resolved", "closed"]);

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
// GET /api/admin/users
// ---------------------------------------------------------------------------

export async function listUsersHandler(req: Request, res: Response): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  const rawStatus = req.query["status"];
  const rawRole   = req.query["role"];

  const status = typeof rawStatus === "string" && rawStatus !== "" ? rawStatus : undefined;
  const role   = typeof rawRole   === "string" && rawRole   !== "" ? rawRole   : undefined;

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
    const page = await listUsers(parsed.limit, parsed.offset, status, role);
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
// PATCH /api/admin/users/:id/status
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

  // Prevent admins from suspending/banning themselves.
  if (userId === req.user!.id && status !== "active") {
    res.status(400).json({
      success: false,
      message: "You cannot change your own status.",
    });
    return;
  }

  try {
    const user = await updateUserStatus(userId, status);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }
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
// PATCH /api/admin/users/:id/role
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

  // Prevent admins from demoting themselves.
  if (userId === req.user!.id && role !== "admin") {
    res.status(400).json({
      success: false,
      message: "You cannot change your own role.",
    });
    return;
  }

  try {
    const user = await updateUserRole(userId, role);
    if (!user) {
      res.status(404).json({ success: false, message: "User not found." });
      return;
    }
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
// PATCH /api/admin/tickets/:id/status
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
    res.status(200).json({ success: true, data: { ticket } });
  } catch (err) {
    req.log.error({ err, ticketId }, "Admin.UpdateTicketStatus: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
