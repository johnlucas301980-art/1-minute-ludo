/**
 * Admin service — Phase 10.1.
 *
 * All database access for admin operations lives here.
 * Controllers call these functions; no SQL escapes this module.
 */

import { pool } from "../db/index.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface AdminUserRow {
  id: string;
  player_id: string;
  full_name: string;
  email: string | null;
  mobile: string | null;
  role: string;
  status: string;
  is_verified: boolean;
  country: string | null;
  last_login_at: Date | null;
  created_at: Date;
}

export interface AdminUserPage {
  rows: AdminUserRow[];
  total: number;
}

export interface AdminStats {
  total_users: number;
  active_users: number;
  suspended_users: number;
  banned_users: number;
  admin_users: number;
  total_matches: number;
  in_progress_matches: number;
  total_wallet_balance: number;
  open_tickets: number;
  in_progress_tickets: number;
}

export interface AdminTicketRow {
  id: string;
  user_id: string;
  player_id: string;
  full_name: string;
  subject: string;
  message: string;
  status: string;
  created_at: Date;
  updated_at: Date;
}

export interface AdminTicketPage {
  rows: AdminTicketRow[];
  total: number;
}

// ---------------------------------------------------------------------------
// Dashboard stats
// ---------------------------------------------------------------------------

export async function getDashboardStats(): Promise<AdminStats> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<AdminStats>(`
    SELECT
      (SELECT COUNT(*)::int            FROM users)                                   AS total_users,
      (SELECT COUNT(*)::int            FROM users WHERE status = 'active')            AS active_users,
      (SELECT COUNT(*)::int            FROM users WHERE status = 'suspended')         AS suspended_users,
      (SELECT COUNT(*)::int            FROM users WHERE status = 'banned')            AS banned_users,
      (SELECT COUNT(*)::int            FROM users WHERE role   = 'admin')             AS admin_users,
      (SELECT COUNT(*)::int            FROM matches)                                  AS total_matches,
      (SELECT COUNT(*)::int            FROM matches WHERE status = 'in_progress')     AS in_progress_matches,
      (SELECT COALESCE(SUM(balance), 0) FROM wallets)                                 AS total_wallet_balance,
      (SELECT COUNT(*)::int            FROM support_tickets WHERE status = 'open')    AS open_tickets,
      (SELECT COUNT(*)::int            FROM support_tickets WHERE status = 'in_progress') AS in_progress_tickets
  `);

  return rows[0]!;
}

// ---------------------------------------------------------------------------
// User management
// ---------------------------------------------------------------------------

export async function listUsers(
  limit: number,
  offset: number,
  status?: string,
  role?: string,
): Promise<AdminUserPage> {
  if (!pool) throw new Error("Database is not available.");

  const conditions: string[] = [];
  const params: unknown[]    = [];

  if (status) {
    params.push(status);
    conditions.push(`status = $${params.length}`);
  }
  if (role) {
    params.push(role);
    conditions.push(`role = $${params.length}`);
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

  params.push(limit);
  const limitPlaceholder = `$${params.length}`;
  params.push(offset);
  const offsetPlaceholder = `$${params.length}`;

  const [countResult, userResult] = await Promise.all([
    pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM users ${where}`,
      params.slice(0, conditions.length),
    ),
    pool.query<AdminUserRow>(
      `SELECT id, player_id, full_name, email, mobile, role, status,
              is_verified, country, last_login_at, created_at
         FROM users
         ${where}
         ORDER BY created_at DESC, id DESC
         LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}`,
      params,
    ),
  ]);

  return {
    rows: userResult.rows,
    total: parseInt(countResult.rows[0]?.total ?? "0", 10),
  };
}

export async function getUserById(userId: string): Promise<AdminUserRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<AdminUserRow>(
    `SELECT id, player_id, full_name, email, mobile, role, status,
            is_verified, country, last_login_at, created_at
       FROM users
      WHERE id = $1`,
    [userId],
  );

  return rows[0] ?? null;
}

export async function updateUserStatus(
  userId: string,
  status: string,
): Promise<AdminUserRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<AdminUserRow>(
    `UPDATE users
        SET status = $1, updated_at = NOW()
      WHERE id = $2
  RETURNING id, player_id, full_name, email, mobile, role, status,
            is_verified, country, last_login_at, created_at`,
    [status, userId],
  );

  return rows[0] ?? null;
}

export async function updateUserRole(
  userId: string,
  role: string,
): Promise<AdminUserRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<AdminUserRow>(
    `UPDATE users
        SET role = $1, updated_at = NOW()
      WHERE id = $2
  RETURNING id, player_id, full_name, email, mobile, role, status,
            is_verified, country, last_login_at, created_at`,
    [role, userId],
  );

  return rows[0] ?? null;
}

// ---------------------------------------------------------------------------
// Ticket management
// ---------------------------------------------------------------------------

export async function listAllTickets(
  limit: number,
  offset: number,
  status?: string,
): Promise<AdminTicketPage> {
  if (!pool) throw new Error("Database is not available.");

  const params: unknown[] = [];
  let where = "";

  if (status) {
    params.push(status);
    where = `WHERE t.status = $${params.length}`;
  }

  params.push(limit);
  const limitPlaceholder = `$${params.length}`;
  params.push(offset);
  const offsetPlaceholder = `$${params.length}`;

  const [countResult, ticketResult] = await Promise.all([
    pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total
         FROM support_tickets t
         ${status ? "WHERE t.status = $1" : ""}`,
      status ? [status] : [],
    ),
    pool.query<AdminTicketRow>(
      `SELECT t.id, t.user_id, u.player_id, u.full_name,
              t.subject, t.message, t.status, t.created_at, t.updated_at
         FROM support_tickets t
         JOIN users u ON u.id = t.user_id
         ${where}
         ORDER BY t.created_at DESC, t.id DESC
         LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}`,
      params,
    ),
  ]);

  return {
    rows: ticketResult.rows,
    total: parseInt(countResult.rows[0]?.total ?? "0", 10),
  };
}

export async function updateTicketStatus(
  ticketId: string,
  status: string,
): Promise<AdminTicketRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const { rows } = await pool.query<AdminTicketRow>(
    `UPDATE support_tickets t
        SET status = $1, updated_at = NOW()
      WHERE t.id = $2
  RETURNING t.id, t.user_id, t.subject, t.message, t.status, t.created_at, t.updated_at`,
    [status, ticketId],
  );

  if (!rows[0]) return null;

  // Fetch user info to populate player_id / full_name
  const userResult = await pool.query<{ player_id: string; full_name: string }>(
    "SELECT player_id, full_name FROM users WHERE id = $1",
    [rows[0].user_id],
  );

  return {
    ...rows[0],
    player_id: userResult.rows[0]?.player_id ?? "",
    full_name:  userResult.rows[0]?.full_name  ?? "",
  };
}
