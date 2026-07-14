/**
 * PostgreSQL connection pool for 1 Minute Ludo backend.
 * Uses the `pg` package. Connection is lazy — the pool is only
 * created when DATABASE_URL is provided.
 */

import pg from "pg";
import { logger } from "../lib/logger";

const { Pool } = pg;

const databaseUrl = process.env["DATABASE_URL"];

if (!databaseUrl) {
  logger.warn("DATABASE_URL is not set — database features are disabled.");
}

/**
 * The shared PostgreSQL connection pool.
 * Will be `null` if DATABASE_URL is not configured.
 */
export const pool: pg.Pool | null = databaseUrl
  ? new Pool({
      connectionString: databaseUrl,
      max: 20,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
    })
  : null;

/**
 * Verify the database connection is alive.
 * Call this during server startup after pool is created.
 */
export async function checkDbConnection(): Promise<void> {
  if (!pool) {
    logger.warn("Skipping DB connection check — pool is not initialized.");
    return;
  }

  const client = await pool.connect();
  try {
    await client.query("SELECT 1");
    logger.info("PostgreSQL connection verified.");
  } finally {
    client.release();
  }
}
