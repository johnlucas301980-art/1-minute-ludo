/**
 * Leaderboard routes — Phase 8.4.
 *
 * GET /api/leaderboard — ranked player leaderboard (auth required).
 */

import { Router, type IRouter } from "express";
import { getLeaderboardHandler } from "../controllers/leaderboard.controller.js";
import { authenticate } from "../middlewares/authenticate.js";

const router: IRouter = Router();

router.get("/leaderboard", authenticate, getLeaderboardHandler);

export default router;
