import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Stubs every required env variable, merging optional overrides. */
function stubEnv(overrides: Record<string, string> = {}): void {
  const base: Record<string, string> = {
    PORT: "5000",
    JWT_ACCESS_SECRET: "access-test-secret",
    JWT_REFRESH_SECRET: "refresh-test-secret",
    JWT_PASSWORD_RESET_SECRET: "reset-test-secret",
  };
  for (const [key, value] of Object.entries({ ...base, ...overrides })) {
    vi.stubEnv(key, value);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("env configuration", () => {
  beforeEach(() => {
    vi.resetModules();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("throws when PORT is not set", async () => {
    stubEnv({ PORT: "" });
    await expect(import("./env.js")).rejects.toThrow(
      "PORT environment variable is required",
    );
  });

  it("throws when PORT is not a valid number", async () => {
    stubEnv({ PORT: "not-a-number" });
    await expect(import("./env.js")).rejects.toThrow(
      'Invalid PORT value: "not-a-number"',
    );
  });

  it("throws when PORT is zero", async () => {
    stubEnv({ PORT: "0" });
    await expect(import("./env.js")).rejects.toThrow('Invalid PORT value: "0"');
  });

  it("throws when JWT_ACCESS_SECRET is not set", async () => {
    stubEnv({ JWT_ACCESS_SECRET: "" });
    await expect(import("./env.js")).rejects.toThrow(
      "JWT_ACCESS_SECRET environment variable is required",
    );
  });

  it("throws when JWT_REFRESH_SECRET is not set", async () => {
    stubEnv({ JWT_REFRESH_SECRET: "" });
    await expect(import("./env.js")).rejects.toThrow(
      "JWT_REFRESH_SECRET environment variable is required",
    );
  });

  it("throws when JWT_PASSWORD_RESET_SECRET is not set", async () => {
    stubEnv({ JWT_PASSWORD_RESET_SECRET: "" });
    await expect(import("./env.js")).rejects.toThrow(
      "JWT_PASSWORD_RESET_SECRET environment variable is required",
    );
  });

  it("exports a correctly shaped env object when all required variables are set", async () => {
    stubEnv({
      DATABASE_URL: "postgresql://localhost/test",
      SESSION_SECRET: "session-secret",
      CORS_ORIGIN: "https://example.com",
      LOG_LEVEL: "debug",
    });
    const { env } = await import("./env.js");

    expect(env.PORT).toBe(5000);
    expect(env.JWT_ACCESS_SECRET).toBe("access-test-secret");
    expect(env.JWT_REFRESH_SECRET).toBe("refresh-test-secret");
    expect(env.JWT_PASSWORD_RESET_SECRET).toBe("reset-test-secret");
    expect(env.DATABASE_URL).toBe("postgresql://localhost/test");
    expect(env.SESSION_SECRET).toBe("session-secret");
    expect(env.CORS_ORIGIN).toBe("https://example.com");
    expect(env.LOG_LEVEL).toBe("debug");
  });

  it("applies sensible defaults when optional variables are absent", async () => {
    // Stub required vars; explicitly delete optional vars so the ?? fallbacks fire.
    stubEnv();
    // vi.stubEnv cannot delete keys — delete directly so process.env[key] === undefined.
    const deleted: Array<[string, string | undefined]> = [
      "DATABASE_URL",
      "SESSION_SECRET",
      "CORS_ORIGIN",
      "LOG_LEVEL",
    ].map((key) => {
      const prev = process.env[key];
      delete process.env[key];
      return [key, prev];
    });

    try {
      const { env } = await import("./env.js");

      expect(env.CORS_ORIGIN).toBe("*");
      expect(env.LOG_LEVEL).toBe("info");
      expect(env.DATABASE_URL).toBe("");
      expect(env.SESSION_SECRET).toBe("dev-secret-change-in-production");
    } finally {
      // Restore deleted keys.
      for (const [key, prev] of deleted) {
        if (prev !== undefined) process.env[key] = prev;
      }
    }
  });
});
