import { beforeEach, describe, expect, it, vi } from "vitest";

const { createTransport, sendMail, warn, info, env } = vi.hoisted(() => ({
  createTransport: vi.fn(),
  sendMail: vi.fn(),
  warn: vi.fn(),
  info: vi.fn(),
  env: {
    SMTP_HOST: "",
    SMTP_PORT: 587,
    SMTP_USER: "",
    SMTP_PASS: "",
    SMTP_FROM: "noreply@test.example",
  },
}));

vi.mock("nodemailer", () => ({
  default: { createTransport },
}));
vi.mock("../config/env", () => ({ env }));
vi.mock("./logger", () => ({
  logger: { warn, info },
}));

import { sendPasswordResetEmail } from "./email.js";

describe("sendPasswordResetEmail", () => {
  beforeEach(() => {
    env.SMTP_HOST = "";
    env.SMTP_PORT = 587;
    env.SMTP_USER = "";
    env.SMTP_PASS = "";
    createTransport.mockReset();
    sendMail.mockReset();
    warn.mockReset();
    info.mockReset();
  });

  it("skips delivery and logs a warning when SMTP is not configured", async () => {
    await sendPasswordResetEmail("player@example.com", "123456");

    expect(createTransport).not.toHaveBeenCalled();
    expect(sendMail).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      { to: "player@example.com" },
      "Password reset email skipped: SMTP is not configured.",
    );
  });

  it("creates a STARTTLS transporter and sends the password reset email", async () => {
    env.SMTP_HOST = "smtp.example.com";
    env.SMTP_USER = "smtp-user";
    env.SMTP_PASS = "smtp-pass";
    sendMail.mockResolvedValue({ messageId: "message-1" });
    createTransport.mockReturnValue({ sendMail });

    await sendPasswordResetEmail("player@example.com", "123456");

    expect(createTransport).toHaveBeenCalledWith({
      host: "smtp.example.com",
      port: 587,
      secure: false,
      auth: { user: "smtp-user", pass: "smtp-pass" },
    });
    expect(sendMail).toHaveBeenCalledWith({
      from: "noreply@test.example",
      to: "player@example.com",
      subject: "Your 1 Minute Ludo password reset code",
      text: expect.stringContaining("Your password reset code is: 123456"),
      html: expect.stringContaining(">123456</h2>"),
    });
    expect(info).toHaveBeenCalledWith(
      { to: "player@example.com" },
      "Password reset email sent.",
    );
  });

  it("skips delivery when any required SMTP setting is missing", async () => {
    env.SMTP_HOST = "smtp.example.com";
    env.SMTP_USER = "smtp-user";

    await sendPasswordResetEmail("player@example.com", "654321");

    expect(createTransport).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledOnce();
  });

  it("propagates transport send errors", async () => {
    env.SMTP_HOST = "smtp.example.com";
    env.SMTP_USER = "smtp-user";
    env.SMTP_PASS = "smtp-pass";
    createTransport.mockReturnValue({ sendMail });
    sendMail.mockRejectedValue(new Error("SMTP unavailable"));

    await expect(
      sendPasswordResetEmail("player@example.com", "123456"),
    ).rejects.toThrow("SMTP unavailable");
    expect(info).not.toHaveBeenCalled();
  });
});