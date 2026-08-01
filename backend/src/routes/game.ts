/**
 * Game routes — Phase 6.5.
 *
 * Mounted at /api by routes/index.ts.
 */

import { Router, type IRouter } from "express";
import { authenticate } from "../middlewares/authenticate.js";
import { getActiveMatch } from "../controllers/game.controller.js";

const router: IRouter = Router();

// GET /api/game/active-match — read-only; no state mutation
router.get("/game/active-match", authenticate, getActiveMatch);

export default router;
