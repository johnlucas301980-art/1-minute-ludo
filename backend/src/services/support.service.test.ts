import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => ({
  pool: {
    query: vi.fn(),
  },
}));

vi.mock("../db/index.js", () => ({ pool }));

import {
  createTicket,
  getFaqs,
  getTicketById,
  getTicketsByUser,
  type SupportTicketRow,
} from "./support.service.js";

function makeTicketRow(overrides: Partial<SupportTicketRow> = {}): SupportTicketRow {
  return {
    id: "ticket-1",
    user_id: "user-1",
    subject: "Unable to join a match",
    message: "The matchmaking queue does not find an opponent.",
    status: "open",
    created_at: new Date("2026-01-01T00:00:00Z"),
    updated_at: new Date("2026-01-01T00:00:00Z"),
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
});

describe("getFaqs", () => {
  it("returns the complete static FAQ list without querying the database", () => {
    const faqs = getFaqs();

    expect(faqs).toHaveLength(10);
    expect(faqs[0]).toEqual({
      id: "faq-1",
      category: "Gameplay",
      question: "How long does a match last?",
      answer: expect.stringContaining("exactly 60 seconds"),
    });
    expect(faqs.every((faq) => faq.id && faq.category && faq.question && faq.answer)).toBe(true);
    expect(pool.query).not.toHaveBeenCalled();
  });

  it("returns the same FAQ data on repeated calls", () => {
    expect(getFaqs()).toEqual(getFaqs());
  });
});

describe("createTicket", () => {
  it("inserts the ticket fields and returns the created row", async () => {
    const row = makeTicketRow();
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await createTicket({
      userId: "user-1",
      subject: "Unable to join a match",
      message: "The matchmaking queue does not find an opponent.",
    });

    expect(result).toEqual(row);
    expect(pool.query).toHaveBeenCalledOnce();
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO support_tickets/i);
    expect(sql).toMatch(/RETURNING id, user_id, subject, message, status, created_at, updated_at/i);
    expect(params).toEqual([
      "user-1",
      "Unable to join a match",
      "The matchmaking queue does not find an opponent.",
    ]);
  });

  it("returns undefined when the database returns no inserted row", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(
      createTicket({ userId: "user-1", subject: "Question", message: "A question about gameplay." }),
    ).resolves.toBeUndefined();
  });

  it("propagates database errors", async () => {
    pool.query.mockRejectedValue(new Error("insert failed"));

    await expect(
      createTicket({ userId: "user-1", subject: "Question", message: "A question about gameplay." }),
    ).rejects.toThrow("insert failed");
  });
});

describe("getTicketsByUser", () => {
  it("returns tickets and parses the total count", async () => {
    const rows = [makeTicketRow(), makeTicketRow({ id: "ticket-2", status: "in_progress" })];
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "7" }] })
      .mockResolvedValueOnce({ rows });

    const result = await getTicketsByUser("user-1", 20, 0);

    expect(result).toEqual({ rows, total: 7 });
    expect(pool.query).toHaveBeenCalledTimes(2);
    expect(pool.query.mock.calls[0][1]).toEqual(["user-1"]);
    expect(pool.query.mock.calls[1][1]).toEqual(["user-1", 20, 0]);
  });

  it("uses zero when the count query has no row", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    await expect(getTicketsByUser("user-1", 10, 30)).resolves.toEqual({
      rows: [],
      total: 0,
    });
  });

  it("runs the count and ticket queries in parallel", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ total: "1" }] })
      .mockResolvedValueOnce({ rows: [makeTicketRow()] });

    await getTicketsByUser("user-1", 5, 10);

    expect(pool.query.mock.calls[0][0]).toMatch(/COUNT\(\*\).*support_tickets/is);
    expect(pool.query.mock.calls[1][0]).toMatch(/ORDER BY created_at DESC, id DESC/is);
  });

  it("propagates a database error from either query", async () => {
    pool.query.mockRejectedValueOnce(new Error("count failed"));

    await expect(getTicketsByUser("user-1", 20, 0)).rejects.toThrow("count failed");
  });
});

describe("getTicketById", () => {
  it("returns the matching ticket scoped to the user", async () => {
    const row = makeTicketRow();
    pool.query.mockResolvedValue({ rows: [row] });

    const result = await getTicketById("user-1", "ticket-1");

    expect(result).toEqual(row);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/WHERE id = \$1/i);
    expect(sql).toMatch(/AND user_id = \$2/i);
    expect(params).toEqual(["ticket-1", "user-1"]);
  });

  it("returns null when the ticket is missing or belongs to another user", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(getTicketById("user-1", "ticket-missing")).resolves.toBeNull();
  });

  it("propagates database errors", async () => {
    pool.query.mockRejectedValue(new Error("lookup failed"));

    await expect(getTicketById("user-1", "ticket-1")).rejects.toThrow("lookup failed");
  });
});