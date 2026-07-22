/**
 * Match history routes — Phase 8.1.
 *
 * GET /api/match/history — paginated completed match history for the
 *                          authenticated player.
 */

import { Router, type IRouter } from "express";
import { getHistory } from "../controllers/history.controller.js";
import { authenticate } from "../middlewares/authenticate.js";

const router: IRouter = Router();

router.get("/match/history", authenticate, getHistory);

export default router;
