import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Request } from "express";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import { requireAdmin } from "./requireAdmin.js";

function makeResponse() {
  const response = {
    status: vi.fn(),
    json: vi.fn(),
  };
  response.status.mockReturnValue(response);
  return response;
}

type AdminRequest = Request & {
  log: { error: ReturnType<typeof vi.fn> };
};

function makeRequest(user?: { id: string; player_id: string }): AdminRequest {
  return {
    user,
    log: { error: vi.fn() },
  } as unknown as AdminRequest;
}

describe("requireAdmin middleware", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("rejects requests without an authenticated user", async () => {
    const response = makeResponse();
    const next = vi.fn();

    await requireAdmin(makeRequest(), response as never, next);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Unauthorised.",
    });
    expect(pool.query).not.toHaveBeenCalled();
    expect(next).not.toHaveBeenCalled();
  });

  it("allows an authenticated admin after checking the database role", async () => {
    pool.query.mockResolvedValue({ rows: [{ role: "admin" }] });
    const request = makeRequest({ id: "user-1", player_id: "player-1" });
    const response = makeResponse();
    const next = vi.fn();

    await requireAdmin(request, response as never, next);

    expect(pool.query).toHaveBeenCalledWith(
      "SELECT role FROM users WHERE id = $1",
      ["user-1"],
    );
    expect(next).toHaveBeenCalledOnce();
    expect(response.status).not.toHaveBeenCalled();
  });

  it("rejects an authenticated non-admin", async () => {
    pool.query.mockResolvedValue({ rows: [{ role: "user" }] });
    const response = makeResponse();
    const next = vi.fn();

    await requireAdmin(
      makeRequest({ id: "user-2", player_id: "player-2" }),
      response as never,
      next,
    );

    expect(response.status).toHaveBeenCalledWith(403);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Forbidden.",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects an authenticated user missing from the database", async () => {
    pool.query.mockResolvedValue({ rows: [] });
    const response = makeResponse();
    const next = vi.fn();

    await requireAdmin(
      makeRequest({ id: "missing-user", player_id: "player-3" }),
      response as never,
      next,
    );

    expect(response.status).toHaveBeenCalledWith(403);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Forbidden.",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("returns a server error and logs unexpected database failures", async () => {
    pool.query.mockRejectedValue(new Error("database unavailable"));
    const request = makeRequest({ id: "user-4", player_id: "player-4" });
    const response = makeResponse();
    const next = vi.fn();

    await requireAdmin(request, response as never, next);

    expect(request.log.error).toHaveBeenCalledOnce();
    expect(response.status).toHaveBeenCalledWith(500);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
    expect(next).not.toHaveBeenCalled();
  });
});