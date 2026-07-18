/**
 * Matchmaking routes — Phase 5.1.
 *
 * REST surface is intentionally read-only.  Queue join and leave are handled
 * exclusively through Socket.IO (find_match / leave_queue events).
 *
 * Mounted at /api/match by routes/index.ts.
 */

import { Router, type IRouter } from "express";
import { getQueueStatus } from "../controllers/matchmaking.controller";
import { authenticate } from "../middlewares/authenticate";

const router: IRouter = Router();

// GET /match/queue/status — read-only; no state mutation
router.get("/match/queue/status", authenticate, getQueueStatus);

export default router;
