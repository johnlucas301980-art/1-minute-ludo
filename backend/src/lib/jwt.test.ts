import { describe, expect, it, vi } from "vitest";
import jwt from "jsonwebtoken";

vi.mock("../config/env.js", () => ({
  env: {
    JWT_ACCESS_SECRET: "access-test-secret",
    JWT_REFRESH_SECRET: "refresh-test-secret",
    JWT_PASSWORD_RESET_SECRET: "password-reset-test-secret",
  },
}));

import {
  signAccessToken,
  signPasswordResetToken,
  signRefreshToken,
  verifyAccessToken,
  verifyPasswordResetToken,
  verifyRefreshToken,
} from "./jwt.js";

describe("JWT utilities", () => {
  it("signs and verifies an access token with its expected payload", () => {
    const token = signAccessToken("user-1", "player-1");

    expect(verifyAccessToken(token)).toMatchObject({
      sub: "user-1",
      player_id: "player-1",
      type: "access",
    });
  });

  it("rejects an access token when verified with the refresh verifier", () => {
    const token = signAccessToken("user-1", "player-1");

    expect(() => verifyRefreshToken(token)).toThrow();
  });

  it("rejects a refresh-type payload signed with the access secret", () => {
    const token = jwt.sign(
      { sub: "user-1", jti: "token-id-1", type: "refresh" },
      "access-test-secret",
    );

    expect(() => verifyAccessToken(token)).toThrow("Invalid token type.");
  });

  it("rejects an access token with an invalid signature", () => {
    const token = signAccessToken("user-1", "player-1");
    const tamperedToken = `${token}tampered`;

    expect(() => verifyAccessToken(tamperedToken)).toThrow();
  });

  it("signs and verifies a refresh token with its expected payload", () => {
    const token = signRefreshToken("user-1", "token-id-1");

    expect(verifyRefreshToken(token)).toMatchObject({
      sub: "user-1",
      jti: "token-id-1",
      type: "refresh",
    });
  });

  it("rejects a refresh token when verified with the access verifier", () => {
    const token = signRefreshToken("user-1", "token-id-1");

    expect(() => verifyAccessToken(token)).toThrow();
  });

  it("rejects an access-type payload signed with the refresh secret", () => {
    const token = jwt.sign(
      { sub: "user-1", player_id: "player-1", type: "access" },
      "refresh-test-secret",
    );

    expect(() => verifyRefreshToken(token)).toThrow("Invalid token type.");
  });

  it("signs and verifies a password reset token with its expected payload", () => {
    const token = signPasswordResetToken("user-1", "otp-row-1");

    expect(verifyPasswordResetToken(token)).toMatchObject({
      sub: "user-1",
      otp_id: "otp-row-1",
      type: "password_reset",
    });
  });

  it("rejects a password reset token with an access-token verifier", () => {
    const token = signPasswordResetToken("user-1", "otp-row-1");

    expect(() => verifyAccessToken(token)).toThrow();
  });

  it("rejects an access-type payload signed with the password reset secret", () => {
    const token = jwt.sign(
      { sub: "user-1", player_id: "player-1", type: "access" },
      "password-reset-test-secret",
    );

    expect(() => verifyPasswordResetToken(token)).toThrow("Invalid token type.");
  });
});