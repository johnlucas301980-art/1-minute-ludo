/**
 * Help & Support controllers — Phase 9.3.
 */

import type { Request, Response } from "express";
import {
  createTicket,
  getFaqs,
  getTicketById,
  getTicketsByUser,
} from "../services/support.service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const DEFAULT_LIMIT = 20;
const MIN_LIMIT = 1;
const MAX_LIMIT = 100;

const SUBJECT_MIN = 3;
const SUBJECT_MAX = 255;
const MESSAGE_MIN = 10;
const MESSAGE_MAX = 5000;

function parsePagination(req: Request): { limit: number; offset: number } | { error: string } {
  const rawLimit = req.query["limit"];
  const rawOffset = req.query["offset"];

  let limit = DEFAULT_LIMIT;
  if (rawLimit !== undefined && rawLimit !== "") {
    const parsed = Number.parseInt(String(rawLimit), 10);
    if (!Number.isFinite(parsed)) {
      limit = DEFAULT_LIMIT;
    } else if (parsed < MIN_LIMIT) {
      return { error: `limit must be at least ${MIN_LIMIT}.` };
    } else if (parsed > MAX_LIMIT) {
      return { error: `limit must not exceed ${MAX_LIMIT}.` };
    } else {
      limit = parsed;
    }
  }

  let offset = 0;
  if (rawOffset !== undefined && rawOffset !== "") {
    const parsed = Number.parseInt(String(rawOffset), 10);
    offset = Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
  }

  return { limit, offset };
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}

function serializeTicket(row: {
  id: string;
  user_id: string;
  subject: string;
  message: string;
  status: string;
  created_at: Date;
  updated_at: Date;
}) {
  return {
    id: row.id,
    user_id: row.user_id,
    subject: row.subject,
    message: row.message,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

// ---------------------------------------------------------------------------
// FAQ
// ---------------------------------------------------------------------------

export function getFaqsHandler(_req: Request, res: Response): void {
  const faqs = getFaqs();
  res.status(200).json({ success: true, data: { faqs } });
}

// ---------------------------------------------------------------------------
// Ticket creation
// ---------------------------------------------------------------------------

export async function createTicketHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const { subject, message } = req.body as Record<string, unknown>;

  if (typeof subject !== "string" || subject.trim().length < SUBJECT_MIN) {
    res.status(400).json({
      success: false,
      message: `subject must be at least ${SUBJECT_MIN} characters.`,
    });
    return;
  }
  if (subject.trim().length > SUBJECT_MAX) {
    res.status(400).json({
      success: false,
      message: `subject must not exceed ${SUBJECT_MAX} characters.`,
    });
    return;
  }

  if (typeof message !== "string" || message.trim().length < MESSAGE_MIN) {
    res.status(400).json({
      success: false,
      message: `message must be at least ${MESSAGE_MIN} characters.`,
    });
    return;
  }
  if (message.trim().length > MESSAGE_MAX) {
    res.status(400).json({
      success: false,
      message: `message must not exceed ${MESSAGE_MAX} characters.`,
    });
    return;
  }

  try {
    const ticket = await createTicket({
      userId: req.user!.id,
      subject: subject.trim(),
      message: message.trim(),
    });

    res.status(201).json({
      success: true,
      data: { ticket: serializeTicket(ticket) },
    });
  } catch (err) {
    req.log.error({ err }, "CreateTicket: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Ticket list
// ---------------------------------------------------------------------------

export async function getTicketsHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const parsed = parsePagination(req);
  if ("error" in parsed) {
    res.status(400).json({ success: false, message: parsed.error });
    return;
  }

  try {
    const page = await getTicketsByUser(req.user!.id, parsed.limit, parsed.offset);
    res.status(200).json({
      success: true,
      data: {
        tickets: page.rows.map(serializeTicket),
        pagination: {
          total: page.total,
          limit: parsed.limit,
          offset: parsed.offset,
        },
      },
    });
  } catch (err) {
    req.log.error({ err }, "GetTickets: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}

// ---------------------------------------------------------------------------
// Single ticket
// ---------------------------------------------------------------------------

export async function getTicketByIdHandler(
  req: Request,
  res: Response,
): Promise<void> {
  const rawId = req.params["id"];
  const ticketId = typeof rawId === "string" ? rawId : undefined;
  if (!ticketId || !isUuid(ticketId)) {
    res.status(400).json({
      success: false,
      message: "A valid ticket id is required.",
    });
    return;
  }

  try {
    const ticket = await getTicketById(req.user!.id, ticketId);
    if (!ticket) {
      res.status(404).json({ success: false, message: "Ticket not found." });
      return;
    }

    res.status(200).json({ success: true, data: { ticket: serializeTicket(ticket) } });
  } catch (err) {
    req.log.error({ err, ticketId }, "GetTicketById: unexpected error.");
    res.status(500).json({
      success: false,
      message: "An unexpected error occurred. Please try again.",
    });
  }
}
