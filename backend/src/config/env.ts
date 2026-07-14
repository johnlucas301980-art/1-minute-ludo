/**
 * Environment configuration for 1 Minute Ludo backend.
 * Variables are read at startup and validated here.
 */

function warnMissing(key: string): void {
  console.warn(`[env] WARNING: ${key} is not set. Some features may be disabled.`);
}

const rawPort = process.env["PORT"];
if (!rawPort) {
  throw new Error("PORT environment variable is required but was not provided.");
}
const port = Number(rawPort);
if (Number.isNaN(port) || port <= 0) {
  throw new Error(`Invalid PORT value: "${rawPort}"`);
}

const databaseUrl = process.env["DATABASE_URL"];
if (!databaseUrl) {
  warnMissing("DATABASE_URL");
}

const sessionSecret = process.env["SESSION_SECRET"];
if (!sessionSecret) {
  warnMissing("SESSION_SECRET");
}

export const env = {
  NODE_ENV: process.env["NODE_ENV"] ?? "development",
  PORT: port,
  DATABASE_URL: databaseUrl ?? "",
  SESSION_SECRET: sessionSecret ?? "dev-secret-change-in-production",
  CORS_ORIGIN: process.env["CORS_ORIGIN"] ?? "*",
  LOG_LEVEL: process.env["LOG_LEVEL"] ?? "info",
} as const;
