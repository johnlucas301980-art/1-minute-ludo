/**
 * Help & Support service — Phase 9.3.
 *
 * All direct database access for support tickets lives here.
 * Static FAQ data is defined in this module and returned without a DB hit.
 */

import { pool } from "../db/index.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SupportTicketRow {
  id: string;
  user_id: string;
  subject: string;
  message: string;
  status: string;
  created_at: Date;
  updated_at: Date;
}

export interface CreateTicketInput {
  userId: string;
  subject: string;
  message: string;
}

export interface TicketPage {
  rows: SupportTicketRow[];
  total: number;
}

export interface FaqItem {
  id: string;
  category: string;
  question: string;
  answer: string;
}

// ---------------------------------------------------------------------------
// Static FAQ data
// ---------------------------------------------------------------------------

const FAQS: FaqItem[] = [
  {
    id: "faq-1",
    category: "Gameplay",
    question: "How long does a match last?",
    answer:
      "Each match lasts exactly 60 seconds. When the timer expires the player who has moved the most pawns to the home zone wins. If both players are tied, the match is declared a draw.",
  },
  {
    id: "faq-2",
    category: "Gameplay",
    question: "What happens if I disconnect during a match?",
    answer:
      "If you disconnect during a match your opponent is automatically awarded the win. We recommend using a stable internet connection to avoid losing matches due to disconnections.",
  },
  {
    id: "faq-3",
    category: "Gameplay",
    question: "How does matchmaking work?",
    answer:
      "When you tap PLAY you are placed in the matchmaking queue. The system automatically pairs you with another player waiting in the queue. If no opponent is found within a reasonable time, you can leave the queue and try again.",
  },
  {
    id: "faq-4",
    category: "Gameplay",
    question: "How is the winner determined?",
    answer:
      "The player who moves all four pawns to the home zone first wins. In 1 Minute mode, if time runs out before that happens, the player with the most pawns in the home zone wins.",
  },
  {
    id: "faq-5",
    category: "Gameplay",
    question: "What are safe squares?",
    answer:
      "Safe squares are special positions on the board where your pawns cannot be captured by an opponent. Landing on a safe square keeps your pawn protected until it moves off.",
  },
  {
    id: "faq-6",
    category: "Account",
    question: "How do I reset my password?",
    answer:
      "On the login screen tap 'Forgot password?' and enter your registered email. You will receive a one-time PIN via email. Enter the PIN to verify your identity, then set a new password.",
  },
  {
    id: "faq-7",
    category: "Account",
    question: "How do I update my profile?",
    answer:
      "Go to the Profile tab, then tap the Edit button. You can update your display name, country, and avatar image. Changes are saved immediately to your account.",
  },
  {
    id: "faq-8",
    category: "Wallet",
    question: "How do I deposit points?",
    answer:
      "Go to the Wallet tab and tap the Deposit button. Enter the amount you wish to add and optionally include a reference. Your balance will be updated immediately after a successful deposit.",
  },
  {
    id: "faq-9",
    category: "Wallet",
    question: "How do I withdraw points?",
    answer:
      "Go to the Wallet tab and tap the Withdraw button. Enter the amount you wish to withdraw. You must have a sufficient balance; withdrawals exceeding your balance will be rejected.",
  },
  {
    id: "faq-10",
    category: "Support",
    question: "How do I contact support?",
    answer:
      "Use the Submit a Request form on this screen to send us a message. Our team reviews every ticket and will get back to you as soon as possible. You can track the status of your submitted tickets in the My Tickets section.",
  },
];

export function getFaqs(): FaqItem[] {
  return FAQS;
}

// ---------------------------------------------------------------------------
// Ticket creation
// ---------------------------------------------------------------------------

export async function createTicket(
  input: CreateTicketInput,
): Promise<SupportTicketRow> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<SupportTicketRow>(
    `INSERT INTO support_tickets (user_id, subject, message)
     VALUES ($1, $2, $3)
     RETURNING id, user_id, subject, message, status, created_at, updated_at`,
    [input.userId, input.subject, input.message],
  );

  return rows[0]!;
}

// ---------------------------------------------------------------------------
// Ticket reads
// ---------------------------------------------------------------------------

export async function getTicketsByUser(
  userId: string,
  limit: number,
  offset: number,
): Promise<TicketPage> {
  if (!pool) throw new Error("Database is not available.");

  const [countResult, ticketResult] = await Promise.all([
    pool.query<{ total: string }>(
      "SELECT COUNT(*) AS total FROM support_tickets WHERE user_id = $1",
      [userId],
    ),
    pool.query<SupportTicketRow>(
      `SELECT id, user_id, subject, message, status, created_at, updated_at
         FROM support_tickets
        WHERE user_id = $1
        ORDER BY created_at DESC, id DESC
        LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    ),
  ]);

  return {
    rows: ticketResult.rows,
    total: parseInt(countResult.rows[0]?.total ?? "0", 10),
  };
}

export async function getTicketById(
  userId: string,
  ticketId: string,
): Promise<SupportTicketRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<SupportTicketRow>(
    `SELECT id, user_id, subject, message, status, created_at, updated_at
       FROM support_tickets
      WHERE id = $1
        AND user_id = $2`,
    [ticketId, userId],
  );

  return rows[0] ?? null;
}
