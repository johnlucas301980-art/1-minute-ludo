import { describe, expect, it, vi } from "vitest";

// vi.mock is hoisted — define the mock return value with vi.hoisted so it is
// available before the factory runs.
const { mockLogger } = vi.hoisted(() => ({
  mockLogger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    debug: vi.fn(),
    trace: vi.fn(),
    fatal: vi.fn(),
  },
}));

vi.mock("pino", () => ({
  default: vi.fn().mockReturnValue(mockLogger),
}));

import pino from "pino";
import { logger } from "./logger.js";

describe("logger", () => {
  it("creates a pino logger instance", () => {
    expect(pino).toHaveBeenCalledOnce();
  });

  it("exports the logger returned by pino", () => {
    expect(logger).toBe(mockLogger);
  });

  it("configures the logger with the info log level by default", () => {
    const mockPino = pino as unknown as ReturnType<typeof vi.fn>;
    const [config] = mockPino.mock.calls[0] as [{ level: string }];
    expect(config.level).toBe("info");
  });

  it("redacts sensitive authorization and cookie headers", () => {
    const mockPino = pino as unknown as ReturnType<typeof vi.fn>;
    const [config] = mockPino.mock.calls[0] as [{ redact: string[] }];
    expect(config.redact).toContain("req.headers.authorization");
    expect(config.redact).toContain("req.headers.cookie");
  });
});
