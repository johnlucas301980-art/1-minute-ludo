/**
 * Minimal SQL migration runner for the 1 Minute Ludo backend.
 *
 * Applies every `.sql` file in `src/db/migrations/` (in filename order) that
 * hasn't already been recorded in the `schema_migrations` table, inside a
 * single transaction per file.
 *
 * Usage: pnpm --filter @workspace/backend run migrate
 */

import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { logger } from "../lib/logger";

const { Pool } = pg;

const migrationsDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "migrations");

async function main(): Promise<void> {
  const databaseUrl = process.env["DATABASE_URL"];
  if (!databaseUrl) {
    throw new Error("DATABASE_URL environment variable is required to run migrations.");
  }

  const pool = new Pool({ connectionString: databaseUrl });

  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name        TEXT PRIMARY KEY,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    const files = (await readdir(migrationsDir))
      .filter((file) => file.endsWith(".sql"))
      .sort();

    const { rows } = await pool.query<{ name: string }>("SELECT name FROM schema_migrations");
    const applied = new Set(rows.map((row) => row.name));

    for (const file of files) {
      if (applied.has(file)) {
        logger.info({ file }, "Migration already applied, skipping.");
        continue;
      }

      const sql = await readFile(path.join(migrationsDir, file), "utf8");
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await client.query(sql);
        await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
        await client.query("COMMIT");
        logger.info({ file }, "Migration applied.");
      } catch (err) {
        await client.query("ROLLBACK");
        throw err;
      } finally {
        client.release();
      }
    }
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  logger.error({ err }, "Migration run failed.");
  process.exitCode = 1;
});
