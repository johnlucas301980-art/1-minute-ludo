/**
 * In-app notification routes — Phase 9.1.
 */

import { Router, type IRouter } from "express";
import {
  getNotificationsHandler,
  markAllNotificationsReadHandler,
  markNotificationReadHandler,
} from "../controllers/notification.controller.js";
import { authenticate } from "../middlewares/authenticate.js";

const router: IRouter = Router();

router.get("/notifications", authenticate, getNotificationsHandler);
router.put("/notifications/read-all", authenticate, markAllNotificationsReadHandler);
router.put("/notifications/:id/read", authenticate, markNotificationReadHandler);

export default router;