import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks
// ---------------------------------------------------------------------------

const {
  createTicket,
  getFaqs,
  getTicketById,
  getTicketsByUser,
} = vi.hoisted(() => ({
  createTicket: vi.fn(),
  getFaqs: vi.fn(),
  getTicketById: vi.fn(),
  getTicketsByUser: vi.fn(),
}));

vi.mock("../services/support.service.js", () => ({
  createTicket,
  getFaqs,
  getTicketById,
  getTicketsByUser,
}));
vi.mock("../lib/logger.js", () => ({
  logger: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

import {
  getFaqsHandler,
  createTicketHandler,
  getTicketsHandler,
  getTicketByIdHandler,
} from "./support.controller.js";
import type { Request, Response } from "express";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const VALID_UUID = "550e8400-e29b-41d4-a716-446655440000";

function makeReq({
  userId = "user-1",
  query = {} as Record<string, string>,
  body = {} as Record<string, unknown>,
  params = {} as Record<string, string>,
} = {}): Request {
  return {
    log: { error: vi.fn() },
    user: { id: userId },
    query,
    body,
    params,
  } as unknown as Request;
}

function makeRes() {
  const res = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
  return res as unknown as Response & typeof res;
}

function makeTicket(overrides = {}) {
  return {
    id: VALID_UUID,
    user_id: "user-1",
    subject: "Test subject",
    message: "Test message body here",
    status: "open",
    created_at: new Date("2026-01-01T00:00:00Z"),
    updated_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

// ---------------------------------------------------------------------------
// getFaqsHandler
// ---------------------------------------------------------------------------

describe("getFaqsHandler", () => {
  it("returns 200 with faqs from the service", () => {
    const faqs = [
      { id: "faq-1", category: "Gameplay", question: "Q?", answer: "A." },
    ];
    getFaqs.mockReturnValue(faqs);

    const res = makeRes();
    getFaqsHandler(makeReq(), res);

    expect(getFaqs).toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { faqs },
    });
  });

  it("returns 200 with an empty faqs array when service returns none", () => {
    getFaqs.mockReturnValue([]);

    const res = makeRes();
    getFaqsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { faqs: [] },
    });
  });
});

// ---------------------------------------------------------------------------
// createTicketHandler
// ---------------------------------------------------------------------------

describe("createTicketHandler", () => {
  it("returns 201 with the created ticket", async () => {
    const ticket = makeTicket();
    createTicket.mockResolvedValue(ticket);

    const res = makeRes();
    await createTicketHandler(
      makeReq({ body: { subject: "Test subject", message: "Test message body here" } }),
      res,
    );

    expect(createTicket).toHaveBeenCalledWith({
      userId: "user-1",
      subject: "Test subject",
      message: "Test message body here",
    });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { ticket: expect.objectContaining({ id: VALID_UUID }) },
    });
  });

  it("trims whitespace from subject and message before saving", async () => {
    createTicket.mockResolvedValue(makeTicket());

    await createTicketHandler(
      makeReq({ body: { subject: "  My subject  ", message: "  My long message body here  " } }),
      makeRes(),
    );

    expect(createTicket).toHaveBeenCalledWith(
      expect.objectContaining({ subject: "My subject", message: "My long message body here" }),
    );
  });

  it("returns 400 when subject is missing", async () => {
    const res = makeRes();
    await createTicketHandler(makeReq({ body: { message: "Long enough message body" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createTicket).not.toHaveBeenCalled();
  });

  it("returns 400 when subject is too short (< 3 chars)", async () => {
    const res = makeRes();
    await createTicketHandler(
      makeReq({ body: { subject: "ab", message: "Long enough message body" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createTicket).not.toHaveBeenCalled();
  });

  it("returns 400 when subject exceeds 255 characters", async () => {
    const res = makeRes();
    await createTicketHandler(
      makeReq({ body: { subject: "s".repeat(256), message: "Long enough message body" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createTicket).not.toHaveBeenCalled();
  });

  it("returns 400 when message is missing", async () => {
    const res = makeRes();
    await createTicketHandler(makeReq({ body: { subject: "Valid subject" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createTicket).not.toHaveBeenCalled();
  });

  it("returns 400 when message is too short (< 10 chars)", async () => {
    const res = makeRes();
    await createTicketHandler(
      makeReq({ body: { subject: "Valid subject", message: "short" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createTicket).not.toHaveBeenCalled();
  });

  it("returns 400 when message exceeds 5000 characters", async () => {
    const res = makeRes();
    await createTicketHandler(
      makeReq({ body: { subject: "Valid subject", message: "m".repeat(5001) } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(createTicket).not.toHaveBeenCalled();
  });

  it("returns 500 when createTicket throws", async () => {
    createTicket.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await createTicketHandler(
      makeReq({ body: { subject: "Valid subject", message: "Long enough message body" } }),
      res,
    );

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// getTicketsHandler
// ---------------------------------------------------------------------------

describe("getTicketsHandler", () => {
  it("returns 200 with paginated tickets using default params", async () => {
    const ticket = makeTicket();
    getTicketsByUser.mockResolvedValue({ rows: [ticket], total: 1 });

    const res = makeRes();
    await getTicketsHandler(makeReq(), res);

    expect(getTicketsByUser).toHaveBeenCalledWith("user-1", 20, 0);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: {
        tickets: [expect.objectContaining({ id: VALID_UUID })],
        pagination: { total: 1, limit: 20, offset: 0 },
      },
    });
  });

  it("forwards valid limit and offset to the service", async () => {
    getTicketsByUser.mockResolvedValue({ rows: [], total: 0 });

    await getTicketsHandler(makeReq({ query: { limit: "10", offset: "5" } }), makeRes());

    expect(getTicketsByUser).toHaveBeenCalledWith("user-1", 10, 5);
  });

  it("returns 400 when limit is below minimum (1)", async () => {
    const res = makeRes();
    await getTicketsHandler(makeReq({ query: { limit: "0" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getTicketsByUser).not.toHaveBeenCalled();
  });

  it("returns 400 when limit exceeds maximum (100)", async () => {
    const res = makeRes();
    await getTicketsHandler(makeReq({ query: { limit: "101" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getTicketsByUser).not.toHaveBeenCalled();
  });

  it("falls back to default limit when limit is non-numeric", async () => {
    getTicketsByUser.mockResolvedValue({ rows: [], total: 0 });

    await getTicketsHandler(makeReq({ query: { limit: "abc" } }), makeRes());

    expect(getTicketsByUser).toHaveBeenCalledWith("user-1", 20, 0);
  });

  it("clamps negative offset to 0 silently", async () => {
    getTicketsByUser.mockResolvedValue({ rows: [], total: 0 });

    await getTicketsHandler(makeReq({ query: { offset: "-5" } }), makeRes());

    expect(getTicketsByUser).toHaveBeenCalledWith("user-1", 20, 0);
  });

  it("returns 500 when getTicketsByUser throws", async () => {
    getTicketsByUser.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getTicketsHandler(makeReq(), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});

// ---------------------------------------------------------------------------
// getTicketByIdHandler
// ---------------------------------------------------------------------------

describe("getTicketByIdHandler", () => {
  it("returns 200 with the ticket when found", async () => {
    const ticket = makeTicket();
    getTicketById.mockResolvedValue(ticket);

    const res = makeRes();
    await getTicketByIdHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(getTicketById).toHaveBeenCalledWith("user-1", VALID_UUID);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { ticket: expect.objectContaining({ id: VALID_UUID }) },
    });
  });

  it("returns 400 when ticket id is not a valid UUID", async () => {
    const res = makeRes();
    await getTicketByIdHandler(makeReq({ params: { id: "not-a-uuid" } }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "A valid ticket id is required.",
    });
    expect(getTicketById).not.toHaveBeenCalled();
  });

  it("returns 400 when ticket id is missing", async () => {
    const res = makeRes();
    await getTicketByIdHandler(makeReq({ params: {} }), res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(getTicketById).not.toHaveBeenCalled();
  });

  it("returns 404 when ticket is not found", async () => {
    getTicketById.mockResolvedValue(null);

    const res = makeRes();
    await getTicketByIdHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Ticket not found.",
    });
  });

  it("returns 500 when getTicketById throws", async () => {
    getTicketById.mockRejectedValue(new Error("db error"));

    const res = makeRes();
    await getTicketByIdHandler(makeReq({ params: { id: VALID_UUID } }), res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  });
});
