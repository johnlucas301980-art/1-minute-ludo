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

const jwtAccessSecret = process.env["JWT_ACCESS_SECRET"];
if (!jwtAccessSecret) {
  throw new Error("JWT_ACCESS_SECRET environment variable is required but was not provided.");
}

const jwtRefreshSecret = process.env["JWT_REFRESH_SECRET"];
if (!jwtRefreshSecret) {
  throw new Error("JWT_REFRESH_SECRET environment variable is required but was not provided.");
}

const jwtPasswordResetSecret = process.env["JWT_PASSWORD_RESET_SECRET"];
if (!jwtPasswordResetSecret) {
  throw new Error("JWT_PASSWORD_RESET_SECRET environment variable is required but was not provided.");
}

// ---------------------------------------------------------------------------
// SMTP — optional; server starts without it.
// Email sending is silently skipped when unconfigured (see lib/email.ts).
// Provider-agnostic: any SMTP-compatible service works (SendGrid, Mailgun,
// Amazon SES, Postmark, Gmail SMTP, etc.) — just set the variables below.
// ---------------------------------------------------------------------------
const smtpHost = process.env["SMTP_HOST"] ?? "";
const smtpPort = Number(process.env["SMTP_PORT"] ?? "587");
const smtpUser = process.env["SMTP_USER"] ?? "";
const smtpPass = process.env["SMTP_PASS"] ?? "";
const smtpFrom = process.env["SMTP_FROM"] ?? "noreply@oneminuteludo.com";

if (!smtpHost || !smtpUser || !smtpPass) {
  warnMissing("SMTP_HOST / SMTP_USER / SMTP_PASS (password reset emails will not be sent until configured)");
}

export const env = {
  NODE_ENV: process.env["NODE_ENV"] ?? "development",
  PORT: port,
  DATABASE_URL: databaseUrl ?? "",
  SESSION_SECRET: sessionSecret ?? "dev-secret-change-in-production",
  CORS_ORIGIN: process.env["CORS_ORIGIN"] ?? "*",
  LOG_LEVEL: process.env["LOG_LEVEL"] ?? "info",
  JWT_ACCESS_SECRET: jwtAccessSecret,
  JWT_REFRESH_SECRET: jwtRefreshSecret,
  JWT_PASSWORD_RESET_SECRET: jwtPasswordResetSecret,
  SMTP_HOST: smtpHost,
  SMTP_PORT: smtpPort,
  SMTP_USER: smtpUser,
  SMTP_PASS: smtpPass,
  SMTP_FROM: smtpFrom,
} as const;
