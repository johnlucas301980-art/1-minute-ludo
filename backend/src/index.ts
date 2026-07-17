import { createServer } from "node:http";
import "./config/env"; // validate env vars at startup
import app from "./app";
import { initSocket } from "./socket";
import { checkDbConnection } from "./db";
import { logger } from "./lib/logger";
import { deleteExpiredOtps } from "./services/password_reset.service";

const port = Number(process.env["PORT"]);

const httpServer = createServer(app);

initSocket(httpServer);

httpServer.listen(port, async () => {
  logger.info({ port }, "1 Minute Ludo API server listening");

  // Non-blocking DB check — warns but doesn't crash if DB is not ready
  checkDbConnection().catch((err) => {
    logger.warn({ err }, "Database connection check failed. DB may not be configured.");
  });
});

// ---------------------------------------------------------------------------
// Automatic cleanup: delete expired password_reset_otps rows every hour.
// unref() ensures this timer does not prevent a clean process exit.
// ---------------------------------------------------------------------------
const OTP_CLEANUP_INTERVAL_MS = 60 * 60 * 1_000; // 1 hour

setInterval(() => {
  deleteExpiredOtps()
    .then((removed) => {
      if (removed > 0) {
        logger.info({ removed }, "Expired password reset OTPs cleaned up.");
      }
    })
    .catch((err) => {
      logger.warn({ err }, "Failed to clean up expired password reset OTPs.");
    });
}, OTP_CLEANUP_INTERVAL_MS).unref();
