/**
 * Email utility for 1 Minute Ludo.
 *
 * Provider-agnostic: all SMTP settings come from environment variables
 * (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM).
 * No email provider is hardcoded. Works with any SMTP-compatible service
 * (SendGrid, Mailgun, Amazon SES, Gmail SMTP, Postmark, etc.).
 *
 * If SMTP is not configured the function logs a warning and returns silently —
 * the server starts and runs without email capability.
 */

import nodemailer from "nodemailer";
import { env } from "../config/env";
import { logger } from "./logger";

/** Returns true when all required SMTP variables are present. */
function isSmtpConfigured(): boolean {
  return Boolean(env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS);
}

/**
 * Build a fresh Nodemailer transporter from env vars.
 * A new instance per call is intentional — avoids stale connection state.
 */
function buildTransporter(): nodemailer.Transporter {
  return nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    // Port 465 uses implicit TLS (SMTPS); any other port uses STARTTLS upgrade.
    secure: env.SMTP_PORT === 465,
    auth: {
      user: env.SMTP_USER,
      pass: env.SMTP_PASS,
    },
  });
}

/**
 * Send a 6-digit password-reset OTP to the given email address.
 *
 * Silently skips (with a warning log) when SMTP is not configured so that the
 * server can operate without email in development environments.
 */
export async function sendPasswordResetEmail(to: string, otp: string): Promise<void> {
  if (!isSmtpConfigured()) {
    logger.warn({ to }, "Password reset email skipped: SMTP is not configured.");
    return;
  }

  const transporter = buildTransporter();

  await transporter.sendMail({
    from: env.SMTP_FROM,
    to,
    subject: "Your 1 Minute Ludo password reset code",
    text: [
      `Your password reset code is: ${otp}`,
      "",
      "This code expires in 15 minutes.",
      "",
      "If you did not request a password reset, you can safely ignore this email.",
    ].join("\n"),
    html: [
      "<p>Your password reset code is:</p>",
      `<h2 style="font-size:2rem;letter-spacing:0.2em;font-family:monospace">${otp}</h2>`,
      "<p>This code expires in <strong>15 minutes</strong>.</p>",
      "<p>If you did not request a password reset, you can safely ignore this email.</p>",
    ].join(""),
  });

  logger.info({ to }, "Password reset email sent.");
}
