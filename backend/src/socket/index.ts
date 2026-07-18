/**
 * Socket.IO server initialization for 1 Minute Ludo realtime layer.
 *
 * This module attaches a Socket.IO server to the shared HTTP server.
 * All game rooms, realtime events, and player state flow through here.
 *
 * Phase 5.1: matchmaking auth middleware and event handlers are registered
 * via setupMatchmakingHandlers().
 */

import { Server as SocketIOServer } from "socket.io";
import type { Server as HTTPServer } from "node:http";
import { logger } from "../lib/logger";
import { setupMatchmakingHandlers } from "./matchmaking";

let io: SocketIOServer | null = null;

/**
 * Initialize the Socket.IO server and attach it to the given HTTP server.
 * Must be called once during server startup, before `httpServer.listen()`.
 */
export function initSocket(httpServer: HTTPServer): SocketIOServer {
  const corsOrigin = process.env["CORS_ORIGIN"] ?? "*";

  io = new SocketIOServer(httpServer, {
    cors: {
      origin: corsOrigin,
      methods: ["GET", "POST"],
      credentials: true,
    },
    transports: ["websocket", "polling"],
    pingTimeout: 20_000,
    pingInterval: 25_000,
  });

  // ── Phase 5.1: matchmaking auth middleware + event handlers ────────────────
  setupMatchmakingHandlers(io);

  // ── Global error handler ───────────────────────────────────────────────────
  io.on("connection", (socket) => {
    socket.on("error", (err) => {
      logger.error({ socketId: socket.id, err }, "Socket error");
    });
  });

  logger.info("Socket.IO server initialized.");

  return io;
}

/**
 * Access the shared Socket.IO server instance.
 * Throws if called before `initSocket()`.
 */
export function getIO(): SocketIOServer {
  if (!io) {
    throw new Error("Socket.IO has not been initialized. Call initSocket() first.");
  }
  return io;
}
