/**
 * Match status lifecycle integration tests.
 *
 * Verifies the corrective schema migration and the real normal-completion
 * path, including Phase 9.1 notification persistence and retry idempotency.
 *
 * Requires:
 *   - a running backend
 *   - DATABASE_URL
 *   - the development migration 0010 applied
 *
 * Run:
 *   node --import tsx backend/tests/phase101_match_status.mjs
 */

import pg from "pg";
import { io } from "socket.io-client";
import { createMatchCompletionNotifications } from "../src/services/notification.service.js";

const { Pool } = pg;
const BASE_URL = process.env["BASE_URL"] ?? "http://localhost:5000";
const API_BASE = `${BASE_URL}/api`;
const PASS = "\x1b[32m✔\x1b[0m";
const FAIL = "\x1b[31m✘\x1b[0m";
const PASSWORD = "StatusLifecyclePass123!";

let passed = 0;
let failed = 0;
const database = new Pool({ connectionString: process.env["DATABASE_URL"] });

function assert(condition, message) {
  if (condition) {
    console.log(`  ${PASS} ${message}`);
    passed++;
  } else {
    console.error(`  ${FAIL} ${message}`);
    failed++;
  }
}

async function apiPost(path, body) {
  return fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function registerAndLogin(suffix) {
  const email = `phase101_${suffix}_${Date.now()}@test.invalid`;
  const registerResponse = await apiPost("/auth/register", {
    full_name: `Phase 10.1 Status User ${suffix}`,
    email,
    password: PASSWORD,
  });
  if (!registerResponse.ok) {
    throw new Error(`Registration failed for ${suffix}: ${await registerResponse.text()}`);
  }

  const loginResponse = await apiPost("/auth/login", {
    identifier: email,
    password: PASSWORD,
  });
  const body = await loginResponse.json();
  const token = body.data?.access_token;
  const userId = body.data?.profile?.id;
  if (!loginResponse.ok || !token || !userId) {
    throw new Error(`Login failed for ${suffix}: ${JSON.stringify(body)}`);
  }
  return { token, userId };
}

function connectSocket(token) {
  return new Promise((resolve, reject) => {
    const socket = io(BASE_URL, {
      auth: { token },
      transports: ["websocket"],
      reconnection: false,
    });
    socket.once("connect", () => resolve(socket));
    socket.once("connect_error", (error) => reject(error));
  });
}

function waitFor(socket, event, timeoutMs = 10_000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Timed out waiting for "${event}" (${timeoutMs} ms)`));
    }, timeoutMs);
    socket.once(event, (data) => {
      clearTimeout(timer);
      resolve(data);
    });
  });
}

function waitForOptional(socket, event, timeoutMs = 10_000) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), timeoutMs);
    socket.once(event, (data) => {
      clearTimeout(timer);
      resolve(data);
    });
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function query(sql, params = []) {
  const result = await database.query(sql, params);
  return result.rows;
}

async function verifyConstraintAndAllowedValues() {
  console.log("\n1. Corrected matches.status constraint");

  const constraintRows = await query(
    `SELECT pg_get_constraintdef(oid) AS definition
       FROM pg_constraint
      WHERE conrelid = 'matches'::regclass
        AND conname = 'matches_status_check'`,
  );
  const definition = constraintRows[0]?.definition ?? "";
  assert(definition.includes("in_progress"), "Constraint allows in_progress");
  assert(!definition.includes("'active'"), "Constraint no longer allows active");

  const roomCode = `T${Date.now().toString(36).slice(-5).toUpperCase()}`;
  const [{ id: matchId }] = await query(
    `INSERT INTO matches (room_code, status, player_count)
     VALUES ($1, 'waiting', 2)
     RETURNING id`,
    [roomCode],
  );

  try {
    for (const status of ["waiting", "in_progress", "finished", "cancelled"]) {
      const result = await database.query(
        "UPDATE matches SET status = $1 WHERE id = $2",
        [status, matchId],
      );
      assert(result.rowCount === 1, `Constraint accepts ${status}`);
    }

    await database.query("BEGIN");
    let activeRejected = false;
    try {
      await database.query(
        "UPDATE matches SET status = 'active' WHERE id = $1",
        [matchId],
      );
    } catch {
      activeRejected = true;
    }
    await database.query("ROLLBACK");
    assert(activeRejected, "Constraint rejects active");
  } finally {
    await database.query("DELETE FROM matches WHERE id = $1", [matchId]);
  }
}

async function setupMatch(suffix) {
  const user1 = await registerAndLogin(`${suffix}A`);
  const user2 = await registerAndLogin(`${suffix}B`);
  const sock1 = await connectSocket(user1.token);
  const sock2 = await connectSocket(user2.token);

  const matchFound1 = waitFor(sock1, "match_found");
  const matchFound2 = waitFor(sock2, "match_found");
  sock1.emit("find_match");
  await sleep(100);
  sock2.emit("find_match");
  const [found1, found2] = await Promise.all([matchFound1, matchFound2]);

  if (found1.matchId !== found2.matchId) {
    throw new Error("Matched sockets received different match IDs.");
  }

  const matchId = found1.matchId;
  const roomReady1 = waitFor(sock1, "room_ready");
  const roomReady2 = waitFor(sock2, "room_ready");
  sock1.emit("join_room", { matchId });
  sock2.emit("join_room", { matchId });
  await Promise.all([roomReady1, roomReady2]);

  const gameStart1 = waitFor(sock1, "game_start", 10_000);
  const gameStart2 = waitFor(sock2, "game_start", 10_000);
  const [gameStart] = await Promise.all([gameStart1, gameStart2]);

  const matchRows = await query("SELECT status FROM matches WHERE id = $1", [matchId]);
  assert(matchRows[0]?.status === "in_progress", "game_start persists in_progress");

  const activeIsFirst = gameStart.firstTurn === found1.color;
  return {
    matchId,
    users: [user1, user2],
    sockets: [sock1, sock2],
    activeSocket: activeIsFirst ? sock1 : sock2,
    waitingSocket: activeIsFirst ? sock2 : sock1,
    activeColor: gameStart.firstTurn,
    waitingColor: activeIsFirst ? found2.color : found1.color,
  };
}

async function playToCompletion(context) {
  let {
    matchId,
    activeSocket,
    waitingSocket,
    activeColor,
    waitingColor,
  } = context;

  const gameOverPromise = new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error("Timed out waiting for normal match completion."));
    }, 300_000);
    context.sockets[0].once("game_over", (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
  context.sockets[1].once("game_over", () => {});

  for (let turn = 0; turn < 600; turn++) {
    const diceActive = waitFor(activeSocket, "dice_rolled", 10_000);
    const diceWaiting = waitFor(waitingSocket, "dice_rolled", 10_000);
    const turnActive = waitForOptional(activeSocket, "turn_changed", 10_000);
    const turnWaiting = waitForOptional(waitingSocket, "turn_changed", 10_000);
    activeSocket.emit("roll_dice", { matchId });
    const [dice] = await Promise.all([diceActive, diceWaiting]);

    if (dice.validMoves.length === 0) {
      await Promise.all([turnActive, turnWaiting]);
      [activeSocket, waitingSocket] = [waitingSocket, activeSocket];
      [activeColor, waitingColor] = [waitingColor, activeColor];
      continue;
    }

    const move = dice.validMoves.find((candidate) => candidate.pawnIndex === 0)
      ?? dice.validMoves[0];
    const pawnMovedActive = waitFor(activeSocket, "pawn_moved", 10_000);
    const pawnMovedWaiting = waitFor(waitingSocket, "pawn_moved", 10_000);
    const gameOverActive = waitFor(activeSocket, "game_over", 250).catch(() => null);
    const gameOverWaiting = waitFor(waitingSocket, "game_over", 250).catch(() => null);
    activeSocket.emit("move_pawn", { matchId, pawnIndex: move.pawnIndex });
    await Promise.all([pawnMovedActive, pawnMovedWaiting]);

    const completed = await Promise.race([
      gameOverActive,
      gameOverWaiting,
      sleep(100).then(() => null),
    ]);
    if (completed) {
      return gameOverPromise;
    }

    const [turnChanged] = await Promise.all([turnActive, turnWaiting]);
    if (!turnChanged) {
      throw new Error("Expected turn_changed after a non-winning pawn move.");
    }
    if (turnChanged.nextTurn !== activeColor) {
      [activeSocket, waitingSocket] = [waitingSocket, activeSocket];
      [activeColor, waitingColor] = [waitingColor, activeColor];
    }
  }

  throw new Error("Normal match did not complete within 600 turns.");
}

async function verifyRealCompletion() {
  console.log("\n2. Real match lifecycle and notification completion");
  const context = await setupMatch("REAL");
  const { matchId, sockets, users } = context;

  try {
    const gameOver = await playToCompletion(context);
    assert(gameOver.reason === "completed", "Normal completion emits completed game_over");

    const matchRows = await query(
      "SELECT status, winner_id FROM matches WHERE id = $1",
      [matchId],
    );
    const match = matchRows[0];
    assert(match?.status === "finished", "Normal completion persists finished");
    assert(
      users.some((user) => user.userId === match?.winner_id),
      "Finished match winner_id belongs to a match player",
    );

    const notificationRows = await query(
      `SELECT user_id, type, event_key
         FROM notifications
        WHERE related_type = 'match'
          AND related_id = $1
        ORDER BY user_id`,
      [matchId],
    );
    assert(notificationRows.length === 2, "Normal completion creates exactly two notifications");
    assert(
      notificationRows.every((row) => row.type === "match_completed"),
      "Both completion notifications have match_completed type",
    );
    assert(
      new Set(notificationRows.map((row) => row.user_id)).size === 2,
      "Winner and loser each receive one notification",
    );
    assert(
      notificationRows.every((row) => row.event_key?.startsWith(`match:${matchId}:completed:`)),
      "Both notifications have per-user completion event keys",
    );

    await createMatchCompletionNotifications(matchId, match.winner_id);
    const retriedRows = await query(
      `SELECT user_id
         FROM notifications
        WHERE related_type = 'match'
          AND related_id = $1`,
      [matchId],
    );
    assert(retriedRows.length === 2, "Retrying completion remains idempotent");
    assert(
      new Set(retriedRows.map((row) => row.user_id)).size === 2,
      "Retry does not create duplicate winner or loser rows",
    );
  } finally {
    for (const socket of sockets) socket.disconnect();
  }
}

async function main() {
  console.log("\nPhase 10.1 — Match Status Constraint Verification\n");
  try {
    await verifyConstraintAndAllowedValues();
    await verifyRealCompletion();
  } catch (error) {
    console.error(`  ${FAIL} ${error.message}`);
    failed++;
  } finally {
    await database.end();
  }

  console.log(`\nPassed: ${passed}  Failed: ${failed}`);
  process.exitCode = failed === 0 ? 0 : 1;
}

main();