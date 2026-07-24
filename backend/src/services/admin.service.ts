/**
 * Admin service — Phase 10.1 through 10.4.
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
      (SELECT COALESCE(SUM(points), 0) FROM wallets)                                 AS total_wallet_balance,
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

// ---------------------------------------------------------------------------
// Match monitoring (Phase 10.3)
// ---------------------------------------------------------------------------

export interface AdminMatchPlayerRow {
  user_id: string;
  player_id: string;
  full_name: string;
  color: string;
  final_rank: number | null;
}

export interface AdminMatchRow {
  id: string;
  room_code: string;
  mode: string;
  status: string;
  entry_points: string; // NUMERIC → string from pg
  player_count: number;
  winner_id: string | null;
  winner_player_id: string | null;
  winner_full_name: string | null;
  started_at: Date | null;
  finished_at: Date | null;
  created_at: Date;
  players: AdminMatchPlayerRow[];
}

export interface AdminMatchPage {
  rows: AdminMatchRow[];
  total: number;
}

export interface AdminMatchEvent {
  type: string;
  description: string;
  timestamp: Date;
  meta?: Record<string, unknown>;
}

/** Valid match statuses (kept in sync with migration 0010). */
export const MATCH_STATUSES = new Set(["waiting", "in_progress", "finished", "cancelled"]);

/** Statuses an admin is allowed to force-cancel. */
export const CANCELLABLE_STATUSES = new Set(["waiting", "in_progress"]);

// Shared player sub-select used by both listMatches and getMatchById.
const PLAYERS_SUBSELECT = `
  (
    SELECT COALESCE(json_agg(
      json_build_object(
        'user_id',    mp.user_id,
        'player_id',  u.player_id,
        'full_name',  u.full_name,
        'color',      mp.color,
        'final_rank', mp.final_rank
      ) ORDER BY mp.joined_at
    ), '[]'::json)
    FROM match_players mp
    JOIN users u ON u.id = mp.user_id
    WHERE mp.match_id = m.id
  ) AS players
`;

/**
 * Returns a paginated list of matches with embedded player info.
 *
 * Supports optional status filter and a free-text search across room_code,
 * player full_name, and player_id.
 */
export async function listMatches(
  limit: number,
  offset: number,
  status?: string,
  search?: string,
): Promise<AdminMatchPage> {
  if (!pool) throw new Error("Database is not available.");

  const conditions: string[] = [];
  const params: unknown[] = [];

  if (status) {
    params.push(status);
    conditions.push(`m.status = $${params.length}`);
  }

  if (search) {
    const term = `%${search}%`;
    params.push(term);
    const n = params.length;
    conditions.push(`(
      m.room_code ILIKE $${n}
      OR EXISTS (
        SELECT 1 FROM match_players mp2
        JOIN users u2 ON u2.id = mp2.user_id
        WHERE mp2.match_id = m.id
          AND (u2.full_name ILIKE $${n} OR u2.player_id ILIKE $${n})
      )
    )`);
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

  const countParams = [...params];
  const { rows: countRows } = await pool.query<{ total: string }>(
    `SELECT COUNT(*)::text AS total FROM matches m ${where}`,
    countParams,
  );
  const total = parseInt(countRows[0]?.total ?? "0", 10);

  params.push(limit, offset);

  type RawRow = Omit<AdminMatchRow, "players"> & { players: string };
  const { rows } = await pool.query<RawRow>(
    `SELECT
       m.id, m.room_code, m.mode, m.status,
       m.entry_points, m.player_count,
       m.winner_id, m.started_at, m.finished_at, m.created_at,
       w.player_id AS winner_player_id,
       w.full_name AS winner_full_name,
       ${PLAYERS_SUBSELECT}
     FROM matches m
     LEFT JOIN users w ON w.id = m.winner_id
     ${where}
     ORDER BY m.created_at DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );

  return {
    rows: rows.map((r) => ({
      ...r,
      players: typeof r.players === "string"
        ? (JSON.parse(r.players) as AdminMatchPlayerRow[])
        : (r.players as unknown as AdminMatchPlayerRow[]),
    })),
    total,
  };
}

/** Fetch a single match with embedded players and winner info. */
export async function getMatchById(matchId: string): Promise<AdminMatchRow | null> {
  if (!pool) return null;

  type RawRow = Omit<AdminMatchRow, "players"> & { players: string };
  const { rows } = await pool.query<RawRow>(
    `SELECT
       m.id, m.room_code, m.mode, m.status,
       m.entry_points, m.player_count,
       m.winner_id, m.started_at, m.finished_at, m.created_at,
       w.player_id AS winner_player_id,
       w.full_name AS winner_full_name,
       ${PLAYERS_SUBSELECT}
     FROM matches m
     LEFT JOIN users w ON w.id = m.winner_id
     WHERE m.id = $1
     LIMIT 1`,
    [matchId],
  );

  if (!rows[0]) return null;
  const r = rows[0];
  return {
    ...r,
    players: typeof r.players === "string"
      ? (JSON.parse(r.players) as AdminMatchPlayerRow[])
      : (r.players as unknown as AdminMatchPlayerRow[]),
  };
}

/**
 * Builds a derived timeline of events for a match from persisted timestamps
 * and match_players rows. No events table exists; this is constructed data.
 */
export async function getMatchEvents(matchId: string): Promise<AdminMatchEvent[]> {
  if (!pool) return [];

  // Fetch the match + players in one query.
  interface RawEvent {
    id: string;
    room_code: string;
    status: string;
    created_at: Date;
    started_at: Date | null;
    finished_at: Date | null;
    user_id: string;
    player_id: string;
    full_name: string;
    color: string;
    joined_at: Date;
  }

  const { rows } = await pool.query<RawEvent>(
    `SELECT
       m.id, m.room_code, m.status, m.created_at, m.started_at, m.finished_at,
       mp.user_id, u.player_id, u.full_name, mp.color, mp.joined_at
     FROM matches m
     LEFT JOIN match_players mp ON mp.match_id = m.id
     LEFT JOIN users u ON u.id = mp.user_id
     WHERE m.id = $1
     ORDER BY mp.joined_at ASC NULLS LAST`,
    [matchId],
  );

  if (rows.length === 0) return [];

  const first = rows[0]!;
  const events: AdminMatchEvent[] = [];

  // 1. Match created
  events.push({
    type: "match_created",
    description: `Match ${first.room_code} created.`,
    timestamp: first.created_at,
    meta: { room_code: first.room_code },
  });

  // 2. Players joined (in join order)
  for (const row of rows) {
    if (row.user_id) {
      events.push({
        type: "player_joined",
        description: `${row.full_name} (${row.player_id}) joined as ${row.color}.`,
        timestamp: row.joined_at,
        meta: { user_id: row.user_id, player_id: row.player_id, color: row.color },
      });
    }
  }

  // 3. Match started
  if (first.started_at) {
    events.push({
      type: "match_started",
      description: "Match started.",
      timestamp: first.started_at,
    });
  }

  // 4. Match ended
  if (first.finished_at) {
    const endType = first.status === "cancelled" ? "match_cancelled" : "match_finished";
    const endDesc = first.status === "cancelled" ? "Match cancelled." : "Match finished.";
    events.push({
      type: endType,
      description: endDesc,
      timestamp: first.finished_at,
    });
  }

  // Sort chronologically.
  events.sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());

  return events;
}

/**
 * Cancels a match (sets status = 'cancelled') and writes an audit log entry.
 *
 * Only matches in 'waiting' or 'in_progress' state may be cancelled.
 * Returns the updated match row, or null if the match does not exist.
 * Throws a domain Error if the match is already in a terminal state.
 */
export async function cancelMatch(
  adminId: string,
  matchId: string,
): Promise<AdminMatchRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const existing = await getMatchById(matchId);
  if (!existing) return null;

  if (!CANCELLABLE_STATUSES.has(existing.status)) {
    throw new Error(
      `Match cannot be cancelled: current status is '${existing.status}'.`,
    );
  }

  const now = new Date();
  await pool.query(
    `UPDATE matches
     SET status = 'cancelled', finished_at = $1
     WHERE id = $2 AND status = ANY($3::text[])`,
    [now, matchId, [...CANCELLABLE_STATUSES]],
  );

  await logAdminAction({
    adminId,
    targetUserId: null,
    action: "match_cancel",
    oldValue: existing.status,
    newValue: "cancelled",
    details: { match_id: matchId, room_code: existing.room_code },
  });

  return getMatchById(matchId);
}

// ---------------------------------------------------------------------------
// Wallet monitoring (Phase 10.4)
// ---------------------------------------------------------------------------

export interface AdminWalletRow {
  wallet_id: string;
  user_id: string;
  player_id: string;
  full_name: string;
  user_status: string;
  points: string;
  total_deposit: string;
  total_withdraw: string;
  transaction_count: number;
  last_transaction_at: Date | null;
  updated_at: Date;
}

export interface AdminWalletPage {
  rows: AdminWalletRow[];
  total: number;
}

export interface AdminWalletTransactionRow {
  id: string;
  user_id: string;
  player_id: string;
  full_name: string;
  type: string;
  amount: string;
  status: string;
  reference: string | null;
  created_at: Date;
}

export interface AdminWalletTransactionPage {
  rows: AdminWalletTransactionRow[];
  total: number;
}

export async function listWallets(
  limit: number,
  offset: number,
  search?: string,
): Promise<AdminWalletPage> {
  if (!pool) throw new Error("Database is not available.");

  const params: unknown[] = [];
  let where = "";
  if (search) {
    params.push(`%${search}%`);
    where = `WHERE u.full_name ILIKE $1
                  OR u.player_id ILIKE $1
                  OR u.email ILIKE $1
                  OR u.mobile ILIKE $1`;
  }

  const countResult = await pool.query<{ total: string }>(
    `SELECT COUNT(*)::text AS total
       FROM wallets w
       JOIN users u ON u.id = w.user_id
       ${where}`,
    params,
  );

  const queryParams = [...params, limit, offset];
  const limitPlaceholder = `$${params.length + 1}`;
  const offsetPlaceholder = `$${params.length + 2}`;
  const { rows } = await pool.query<AdminWalletRow>(
    `SELECT
       w.id AS wallet_id,
       w.user_id,
       u.player_id,
       u.full_name,
       u.status AS user_status,
       w.points,
       w.total_deposit,
       w.total_withdraw,
       COUNT(t.id)::int AS transaction_count,
       MAX(t.created_at) AS last_transaction_at,
       w.updated_at
     FROM wallets w
     JOIN users u ON u.id = w.user_id
     LEFT JOIN transactions t ON t.user_id = w.user_id
     ${where}
     GROUP BY w.id, w.user_id, u.player_id, u.full_name, u.status,
              w.points, w.total_deposit, w.total_withdraw, w.updated_at
     ORDER BY w.updated_at DESC, w.id DESC
     LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}`,
    queryParams,
  );

  return {
    rows,
    total: parseInt(countResult.rows[0]?.total ?? "0", 10),
  };
}

export async function listWalletTransactions(
  userId: string,
  limit: number,
  offset: number,
): Promise<AdminWalletTransactionPage> {
  if (!pool) throw new Error("Database is not available.");

  const [countResult, transactionResult] = await Promise.all([
    pool.query<{ total: string }>(
      "SELECT COUNT(*)::text AS total FROM transactions WHERE user_id = $1",
      [userId],
    ),
    pool.query<AdminWalletTransactionRow>(
      `SELECT t.id, t.user_id, u.player_id, u.full_name,
              t.type, t.amount, t.status, t.reference, t.created_at
         FROM transactions t
         JOIN users u ON u.id = t.user_id
        WHERE t.user_id = $1
        ORDER BY t.created_at DESC, t.id DESC
        LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    ),
  ]);

  return {
    rows: transactionResult.rows,
    total: parseInt(countResult.rows[0]?.total ?? "0", 10),
  };
}

// ---------------------------------------------------------------------------
// Reports (Phase 10.4)
// ---------------------------------------------------------------------------

export interface AdminReport {
  from: Date;
  to: Date;
  users: {
    total: number;
    new_users: number;
    active: number;
    suspended: number;
    banned: number;
  };
  matches: {
    total: number;
    waiting: number;
    in_progress: number;
    finished: number;
    cancelled: number;
  };
  wallets: {
    wallet_count: number;
    total_points: string;
    total_deposit: string;
    total_withdraw: string;
  };
  transactions: {
    total: number;
    deposit: string;
    withdraw: string;
    reward: string;
    entry_fee: string;
    refund: string;
  };
  support: {
    open: number;
    in_progress: number;
    resolved: number;
    closed: number;
  };
}

function asNumber(value: string | number | null | undefined): number {
  return Number(value ?? 0);
}

export async function getAdminReport(from: Date, to: Date): Promise<AdminReport> {
  if (!pool) throw new Error("Database is not available.");

  const [users, matches, wallets, transactions, support] = await Promise.all([
    pool.query<{
      total: string;
      new_users: string;
      active: string;
      suspended: string;
      banned: string;
    }>(
      `SELECT
         COUNT(*)::text AS total,
         COUNT(*) FILTER (WHERE created_at >= $1 AND created_at < $2)::text AS new_users,
         COUNT(*) FILTER (WHERE status = 'active')::text AS active,
         COUNT(*) FILTER (WHERE status = 'suspended')::text AS suspended,
         COUNT(*) FILTER (WHERE status = 'banned')::text AS banned
       FROM users`,
      [from, to],
    ),
    pool.query<{
      total: string;
      waiting: string;
      in_progress: string;
      finished: string;
      cancelled: string;
    }>(
      `SELECT
         COUNT(*)::text AS total,
         COUNT(*) FILTER (WHERE status = 'waiting')::text AS waiting,
         COUNT(*) FILTER (WHERE status = 'in_progress')::text AS in_progress,
         COUNT(*) FILTER (WHERE status = 'finished')::text AS finished,
         COUNT(*) FILTER (WHERE status = 'cancelled')::text AS cancelled
       FROM matches
      WHERE created_at >= $1 AND created_at < $2`,
      [from, to],
    ),
    pool.query<{
      wallet_count: string;
      total_points: string;
      total_deposit: string;
      total_withdraw: string;
    }>(
      `SELECT COUNT(*)::text AS wallet_count,
              COALESCE(SUM(points), 0)::text AS total_points,
              COALESCE(SUM(total_deposit), 0)::text AS total_deposit,
              COALESCE(SUM(total_withdraw), 0)::text AS total_withdraw
         FROM wallets`,
    ),
    pool.query<{
      total: string;
      deposit: string;
      withdraw: string;
      reward: string;
      entry_fee: string;
      refund: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE created_at >= $1 AND created_at < $2)::text AS total,
         COALESCE(SUM(amount) FILTER (WHERE type = 'deposit'
           AND created_at >= $1 AND created_at < $2), 0)::text AS deposit,
         COALESCE(SUM(amount) FILTER (WHERE type = 'withdraw'
           AND created_at >= $1 AND created_at < $2), 0)::text AS withdraw,
         COALESCE(SUM(amount) FILTER (WHERE type = 'reward'
           AND created_at >= $1 AND created_at < $2), 0)::text AS reward,
         COALESCE(SUM(amount) FILTER (WHERE type = 'entry_fee'
           AND created_at >= $1 AND created_at < $2), 0)::text AS entry_fee,
         COALESCE(SUM(amount) FILTER (WHERE type = 'refund'
           AND created_at >= $1 AND created_at < $2), 0)::text AS refund
       FROM transactions`,
      [from, to],
    ),
    pool.query<{
      open: string;
      in_progress: string;
      resolved: string;
      closed: string;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'open')::text AS open,
         COUNT(*) FILTER (WHERE status = 'in_progress')::text AS in_progress,
         COUNT(*) FILTER (WHERE status = 'resolved')::text AS resolved,
         COUNT(*) FILTER (WHERE status = 'closed')::text AS closed
       FROM support_tickets`,
    ),
  ]);

  const userRow = users.rows[0]!;
  const matchRow = matches.rows[0]!;
  const walletRow = wallets.rows[0]!;
  const transactionRow = transactions.rows[0]!;
  const supportRow = support.rows[0]!;

  return {
    from,
    to,
    users: {
      total: asNumber(userRow.total),
      new_users: asNumber(userRow.new_users),
      active: asNumber(userRow.active),
      suspended: asNumber(userRow.suspended),
      banned: asNumber(userRow.banned),
    },
    matches: {
      total: asNumber(matchRow.total),
      waiting: asNumber(matchRow.waiting),
      in_progress: asNumber(matchRow.in_progress),
      finished: asNumber(matchRow.finished),
      cancelled: asNumber(matchRow.cancelled),
    },
    wallets: {
      wallet_count: asNumber(walletRow.wallet_count),
      total_points: walletRow.total_points,
      total_deposit: walletRow.total_deposit,
      total_withdraw: walletRow.total_withdraw,
    },
    transactions: {
      total: asNumber(transactionRow.total),
      deposit: transactionRow.deposit,
      withdraw: transactionRow.withdraw,
      reward: transactionRow.reward,
      entry_fee: transactionRow.entry_fee,
      refund: transactionRow.refund,
    },
    support: {
      open: asNumber(supportRow.open),
      in_progress: asNumber(supportRow.in_progress),
      resolved: asNumber(supportRow.resolved),
      closed: asNumber(supportRow.closed),
    },
  };
}

// ---------------------------------------------------------------------------
// Settings (Phase 10.4)
// ---------------------------------------------------------------------------

export interface AdminSettingRow {
  id: string;
  key: string;
  value: string;
  updated_at: Date;
}

export async function listSettings(): Promise<AdminSettingRow[]> {
  if (!pool) throw new Error("Database is not available.");
  const { rows } = await pool.query<AdminSettingRow>(
    `SELECT id, key, value, updated_at
       FROM settings
      ORDER BY key ASC`,
  );
  return rows;
}

export async function updateSetting(
  key: string,
  value: string,
): Promise<AdminSettingRow> {
  if (!pool) throw new Error("Database is not available.");
  const { rows } = await pool.query<AdminSettingRow>(
    `INSERT INTO settings (key, value)
     VALUES ($1, $2)
     ON CONFLICT (key) DO UPDATE
       SET value = EXCLUDED.value, updated_at = NOW()
     RETURNING id, key, value, updated_at`,
    [key, value],
  );
  return rows[0]!;
}
