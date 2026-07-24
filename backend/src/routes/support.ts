/**
 * Help & Support routes — Phase 9.3.
 */

import { Router, type IRouter } from "express";
import {
  createTicketHandler,
  getFaqsHandler,
  getTicketByIdHandler,
  getTicketsHandler,
} from "../controllers/support.controller.js";
import { authenticate } from "../middlewares/authenticate.js";

const router: IRouter = Router();

router.get("/support/faqs", authenticate, getFaqsHandler);
router.post("/support/tickets", authenticate, createTicketHandler);
router.get("/support/tickets", authenticate, getTicketsHandler);
router.get("/support/tickets/:id", authenticate, getTicketByIdHandler);

export default router;
