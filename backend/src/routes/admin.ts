/**
 * Admin routes — Phase 10.1.
 *
 * All routes require a valid access token (authenticate) AND admin role
 * (requireAdmin). The role check hits the database on every request to
 * avoid stale JWT grants persisting after a demotion.
 */

import { Router, type IRouter } from "express";
import { authenticate }   from "../middlewares/authenticate.js";
import { requireAdmin }   from "../middlewares/requireAdmin.js";
import {
  getStatsHandler,
  listUsersHandler,
  getUserHandler,
  updateUserStatusHandler,
  updateUserRoleHandler,
  listTicketsHandler,
  updateTicketStatusHandler,
} from "../controllers/admin.controller.js";

const router: IRouter = Router();

// Dashboard
router.get("/admin/stats",                   authenticate, requireAdmin, getStatsHandler);

// User management
router.get("/admin/users",                   authenticate, requireAdmin, listUsersHandler);
router.get("/admin/users/:id",               authenticate, requireAdmin, getUserHandler);
router.patch("/admin/users/:id/status",      authenticate, requireAdmin, updateUserStatusHandler);
router.patch("/admin/users/:id/role",        authenticate, requireAdmin, updateUserRoleHandler);

// Ticket management
router.get("/admin/tickets",                 authenticate, requireAdmin, listTicketsHandler);
router.patch("/admin/tickets/:id/status",    authenticate, requireAdmin, updateTicketStatusHandler);

export default router;
