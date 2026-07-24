/**
 * Admin service — Phase 10.1 + 10.2.
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

// Phase 10.2 — Audit log
export interface AuditLogRow {
  id: string;
  admin_id: string;
  admin_player_id: string;
  admin_full_name: string;
  target_user_id: string | null;
  target_player_id: string | null;
  target_full_name: string | null;
  action: string;
  old_value: string | null;
  new_value: string | null;
  details: Record<string, unknown> | null;
  created_at: Date;
}

export interface AuditLogPage {
  rows: AuditLogRow[];
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
// User management (Phase 10.1 — updated in 10.2 to support search)
// ---------------------------------------------------------------------------

export async function listUsers(
  limit: number,
  offset: number,
  status?: string,
  role?: string,
  search?: string,
): Promise<AdminUserPage> {
  if (!pool) throw new Error("Database is not available.");

  const conditions: string[] = [];
  const filterParams: unknown[] = [];

  if (status) {
    filterParams.push(status);
    conditions.push(`status = $${filterParams.length}`);
  }
  if (role) {
    filterParams.push(role);
    conditions.push(`role = $${filterParams.length}`);
  }
  if (search) {
    const term = `%${search}%`;
    filterParams.push(term);
    const n = filterParams.length;
    conditions.push(
      `(full_name ILIKE $${n} OR email ILIKE $${n} OR player_id ILIKE $${n} OR mobile ILIKE $${n})`,
    );
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

  const queryParams = [...filterParams, limit, offset];
  const limitP  = `$${filterParams.length + 1}`;
  const offsetP = `$${filterParams.length + 2}`;

  const [countResult, userResult] = await Promise.all([
    pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM users ${where}`,
      filterParams,
    ),
    pool.query<AdminUserRow>(
      `SELECT id, player_id, full_name, email, mobile, role, status,
              is_verified, country, last_login_at, created_at
         FROM users
         ${where}
         ORDER BY created_at DESC, id DESC
         LIMIT ${limitP} OFFSET ${offsetP}`,
      queryParams,
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

// ---------------------------------------------------------------------------
// Phase 10.2 — Audit log
// ---------------------------------------------------------------------------

export async function logAdminAction(opts: {
  adminId: string;
  targetUserId?: string | null;
  action: string;
  oldValue?: string | null;
  newValue?: string | null;
  details?: Record<string, unknown> | null;
}): Promise<void> {
  if (!pool) throw new Error("Database is not available.");

  await pool.query(
    `INSERT INTO admin_audit_log
       (admin_id, target_user_id, action, old_value, new_value, details)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [
      opts.adminId,
      opts.targetUserId ?? null,
      opts.action,
      opts.oldValue ?? null,
      opts.newValue ?? null,
      opts.details ? JSON.stringify(opts.details) : null,
    ],
  );
}

export async function getAuditLog(
  limit: number,
  offset: number,
  adminId?: string,
  targetUserId?: string,
  action?: string,
): Promise<AuditLogPage> {
  if (!pool) throw new Error("Database is not available.");

  const conditions: string[] = [];
  const filterParams: unknown[] = [];

  if (adminId) {
    filterParams.push(adminId);
    conditions.push(`a.admin_id = $${filterParams.length}`);
  }
  if (targetUserId) {
    filterParams.push(targetUserId);
    conditions.push(`a.target_user_id = $${filterParams.length}`);
  }
  if (action) {
    filterParams.push(action);
    conditions.push(`a.action = $${filterParams.length}`);
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";
  const queryParams = [...filterParams, limit, offset];
  const limitP  = `$${filterParams.length + 1}`;
  const offsetP = `$${filterParams.length + 2}`;

  const [countResult, logResult] = await Promise.all([
    pool.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total
         FROM admin_audit_log a
         ${where}`,
      filterParams,
    ),
    pool.query<AuditLogRow>(
      `SELECT
         a.id,
         a.admin_id,
         adm.player_id  AS admin_player_id,
         adm.full_name  AS admin_full_name,
         a.target_user_id,
         tgt.player_id  AS target_player_id,
         tgt.full_name  AS target_full_name,
         a.action,
         a.old_value,
         a.new_value,
         a.details,
         a.created_at
       FROM admin_audit_log a
       JOIN users adm ON adm.id = a.admin_id
       LEFT JOIN users tgt ON tgt.id = a.target_user_id
       ${where}
       ORDER BY a.created_at DESC, a.id DESC
       LIMIT ${limitP} OFFSET ${offsetP}`,
      queryParams,
    ),
  ]);

  return {
    rows: logResult.rows,
    total: parseInt(countResult.rows[0]?.total ?? "0", 10),
  };
}

// ---------------------------------------------------------------------------
// Phase 10.2 — Dedicated action functions (ban / unban / promote / demote)
// Each returns the updated user and logs the action atomically.
// ---------------------------------------------------------------------------

export async function banUser(
  adminId: string,
  userId: string,
): Promise<AdminUserRow | null> {
  if (!pool) throw new Error("Database is not available.");

  // Fetch current status for audit log old_value.
  const current = await getUserById(userId);
  if (!current) return null;

  const updated = await updateUserStatus(userId, "banned");
  if (!updated) return null;

  await logAdminAction({
    adminId,
    targetUserId: userId,
    action: "ban",
    oldValue: current.status,
    newValue: "banned",
    details: { player_id: current.player_id },
  });

  return updated;
}

export async function unbanUser(
  adminId: string,
  userId: string,
): Promise<AdminUserRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const current = await getUserById(userId);
  if (!current) return null;

  const updated = await updateUserStatus(userId, "active");
  if (!updated) return null;

  await logAdminAction({
    adminId,
    targetUserId: userId,
    action: "unban",
    oldValue: current.status,
    newValue: "active",
    details: { player_id: current.player_id },
  });

  return updated;
}

export async function promoteUser(
  adminId: string,
  userId: string,
): Promise<AdminUserRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const current = await getUserById(userId);
  if (!current) return null;

  const updated = await updateUserRole(userId, "admin");
  if (!updated) return null;

  await logAdminAction({
    adminId,
    targetUserId: userId,
    action: "promote",
    oldValue: current.role,
    newValue: "admin",
    details: { player_id: current.player_id },
  });

  return updated;
}

export async function demoteUser(
  adminId: string,
  userId: string,
): Promise<AdminUserRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const current = await getUserById(userId);
  if (!current) return null;

  const updated = await updateUserRole(userId, "player");
  if (!updated) return null;

  await logAdminAction({
    adminId,
    targetUserId: userId,
    action: "demote",
    oldValue: current.role,
    newValue: "player",
    details: { player_id: current.player_id },
  });

  return updated;
}
