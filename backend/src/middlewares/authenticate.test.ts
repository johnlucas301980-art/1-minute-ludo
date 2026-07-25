import { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Request } from "express";

const { verifyAccessToken } = vi.hoisted(() => ({
  verifyAccessToken: vi.fn(),
}));

vi.mock("../lib/jwt", () => ({ verifyAccessToken }));

import { authenticate } from "./authenticate.js";

function makeResponse() {
  const response = {
    status: vi.fn(),
    json: vi.fn(),
  };
  response.status.mockReturnValue(response);
  return response;
}

function makeRequest(authorization?: string): Request {
  return {
    headers: authorization === undefined ? {} : { authorization },
  } as Request;
}

describe("authenticate middleware", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("rejects requests without an authorization header", () => {
    const response = makeResponse();
    const next = vi.fn();

    authenticate(makeRequest(), response as never, next);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Unauthorised.",
    });
    expect(next).not.toHaveBeenCalled();
    expect(verifyAccessToken).not.toHaveBeenCalled();
  });

  it("rejects authorization headers that are not Bearer tokens", () => {
    const response = makeResponse();
    const next = vi.fn();

    authenticate(makeRequest("Basic credentials"), response as never, next);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Unauthorised.",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("verifies a Bearer token, attaches the user, and continues", () => {
    verifyAccessToken.mockReturnValue({
      sub: "user-1",
      player_id: "player-1",
      type: "access",
    });
    const request = makeRequest("Bearer access-token");
    const response = makeResponse();
    const next = vi.fn();

    authenticate(request, response as never, next);

    expect(verifyAccessToken).toHaveBeenCalledWith("access-token");
    expect(request.user).toEqual({ id: "user-1", player_id: "player-1" });
    expect(next).toHaveBeenCalledOnce();
    expect(response.status).not.toHaveBeenCalled();
  });

  it("maps an expired token to an expired-token response", () => {
    verifyAccessToken.mockImplementation(() => {
      throw new TokenExpiredError("jwt expired", new Date());
    });
    const response = makeResponse();
    const next = vi.fn();

    authenticate(makeRequest("Bearer expired-token"), response as never, next);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Access token expired.",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("maps an invalid JWT to an invalid-token response", () => {
    verifyAccessToken.mockImplementation(() => {
      throw new JsonWebTokenError("invalid signature");
    });
    const response = makeResponse();
    const next = vi.fn();

    authenticate(makeRequest("Bearer invalid-token"), response as never, next);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Invalid access token.",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("treats unexpected verification errors as unauthorized", () => {
    verifyAccessToken.mockImplementation(() => {
      throw new Error("unexpected failure");
    });
    const response = makeResponse();
    const next = vi.fn();

    authenticate(makeRequest("Bearer problematic-token"), response as never, next);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(response.json).toHaveBeenCalledWith({
      success: false,
      message: "Unauthorised.",
    });
    expect(next).not.toHaveBeenCalled();
  });
});