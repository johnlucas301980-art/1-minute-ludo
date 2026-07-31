/**
 * Public geo routes — country detection and listing.
 * No authentication required; the mobile app calls these at startup.
 */

import { Router, type IRouter } from "express";
import { detectCountryHandler } from "../controllers/country.controller.js";

const router: IRouter = Router();

// GET /api/geo/detect
// Detects the caller's country from IP and returns the full country list.
router.get("/geo/detect", detectCountryHandler);

export default router;
