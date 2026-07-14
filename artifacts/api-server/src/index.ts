import { createServer } from "node:http";
import "./config/env"; // validate env vars at startup
import app from "./app";
import { initSocket } from "./socket";
import { checkDbConnection } from "./db";
import { logger } from "./lib/logger";

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
