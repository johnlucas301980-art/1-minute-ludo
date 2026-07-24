/**
 * Admin routes — Phase 10.1 + 10.2.
 *
 * All routes require a valid access token (authenticate) AND admin role
 * (requireAdmin). The role check hits the database on every request to
 * avoid stale JWT grants persisting after a demotion.
 */

import { Router, type IRouter } from "express";
import { authenticate }   from "../middlewares/authenticate.js";
import { requireAdmin }   from "../middlewares/requireAdmin.js";
import {
  // Phase 10.1
  getStatsHandler,
  listUsersHandler,
  getUserHandler,
  updateUserStatusHandler,
  updateUserRoleHandler,
  listTicketsHandler,
  updateTicketStatusHandler,
  // Phase 10.2
  banUserHandler,
  unbanUserHandler,
  promoteUserHandler,
  demoteUserHandler,
  getAuditLogHandler,
} from "../controllers/admin.controller.js";

const router: IRouter = Router();

// ── Dashboard ────────────────────────────────────────────────────────────────
router.get("/admin/stats",                    authenticate, requireAdmin, getStatsHandler);

// ── User management (Phase 10.1) ─────────────────────────────────────────────
router.get("/admin/users",                    authenticate, requireAdmin, listUsersHandler);
router.get("/admin/users/:id",                authenticate, requireAdmin, getUserHandler);
router.patch("/admin/users/:id/status",       authenticate, requireAdmin, updateUserStatusHandler);
router.patch("/admin/users/:id/role",         authenticate, requireAdmin, updateUserRoleHandler);

// ── Player actions (Phase 10.2) ───────────────────────────────────────────────
router.post("/admin/users/:id/ban",           authenticate, requireAdmin, banUserHandler);
router.post("/admin/users/:id/unban",         authenticate, requireAdmin, unbanUserHandler);
router.post("/admin/users/:id/promote",       authenticate, requireAdmin, promoteUserHandler);
router.post("/admin/users/:id/demote",        authenticate, requireAdmin, demoteUserHandler);

// ── Ticket management (Phase 10.1) ───────────────────────────────────────────
router.get("/admin/tickets",                  authenticate, requireAdmin, listTicketsHandler);
router.patch("/admin/tickets/:id/status",     authenticate, requireAdmin, updateTicketStatusHandler);

// ── Audit log (Phase 10.2) ────────────────────────────────────────────────────
router.get("/admin/audit-log",                authenticate, requireAdmin, getAuditLogHandler);

export default router;
