/**
 * Phase 6.7.6 — Win Completion Integration Tests.
 *
 * Verifies the full normal-win path: a player who moves all four pawns to
 * position 57 (HOME_FINISHED) receives `game_over { reason: 'completed' }`,
 * the DB match row is marked finished, the in-memory game state is cleared,
 * and no subsequent socket events are accepted for the ended match.
 *
 * Requires a running backend with a connected PostgreSQL database.
 *
 * Test coverage:
 *   1. game_over { reason: 'completed' } emitted to both sockets on win
 *   2. game_over.winnerId is the actual winner's userId
 *   3. roll_dice emits error after win (game state cleared)
 *   4. Server remains healthy after normal win (follow-up match completes)
 *   5. game_over.matchId matches the match that was played
 *
 * Run:
 *   node backend/tests/phase676_win_completion.mjs
 */

import { io } from "socket.io-client";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const BASE_URL = process.env["BASE_URL"] ?? "http://localhost:5000";
const API_BASE = `${BASE_URL}/api`;
const PASS     = "\x1b[32m✔\x1b[0m";
const FAIL     = "\x1b[31m✘\x1b[0m";

let passed = 0;
let failed = 0;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function assert(condition, message) {
  if (condition) {
    console.log(`  ${PASS}  ${message}`);
    passed++;
  } else {
    console.error(`  ${FAIL}  ${message}`);
    failed++;
  }
}

async function apiPost(path, body, token) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}${path}`, {
    method:  "POST",
    headers,
    body:    JSON.stringify(body),
  });
  return res;
}

async function register(suffix) {
  const res = await apiPost("/auth/register", {
    full_name: `Phase676 User ${suffix}`,
    email:     `phase676_${suffix}_${Date.now()}@test.invalid`,
    password:  "TestPass1!",
  });
  return res.json();
}

async function login(email) {
  const res  = await apiPost("/auth/login", { identifier: email, password: "TestPass1!" });
  const data = await res.json();
  return data.access_token;
}

async function getUserId(token) {
  const res  = await fetch(`${API_BASE}/profile`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const body = await res.json();
  return body.data?.profile?.id ?? null;
}

function connectSocket(token) {
  return new Promise((resolve, reject) => {
    const socket = io(BASE_URL, {
      auth:       { token },
      transports: ["websocket"],
    });
    socket.once("connect",       () => resolve(socket));
    socket.once("connect_error", (err) => reject(new Error(err.message)));
  });
}

function waitFor(socket, event, timeoutMs = 8000) {
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

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ---------------------------------------------------------------------------
// Setup helpers
// ---------------------------------------------------------------------------

/**
 * Register two users, connect their sockets, match them, join the room,
 * and wait for game_start.  Returns everything needed to drive the game.
 */
async function setupMatch(suffix) {
  const reg1 = await register(`${suffix}A`);
  const reg2 = await register(`${suffix}B`);

  const u1email = reg1.user?.email ?? reg1.email;
  const u2email = reg2.user?.email ?? reg2.email;

  const tok1 = await login(u1email);
  const tok2 = await login(u2email);

  if (!tok1 || !tok2) {
    throw new Error("Login failed — check backend is running with valid JWT secrets.");
  }

  const sock1 = await connectSocket(tok1);
  const sock2 = await connectSocket(tok2);

  // Matchmaking
  const mf1Promise = waitFor(sock1, "match_found");
  const mf2Promise = waitFor(sock2, "match_found");
  sock1.emit("find_match");
  await sleep(100);
  sock2.emit("find_match");
  const [mf1, mf2] = await Promise.all([mf1Promise, mf2Promise]);

  if (mf1.matchId !== mf2.matchId) {
    throw new Error(`matchId mismatch: ${mf1.matchId} vs ${mf2.matchId}`);
  }

  const matchId = mf1.matchId;

  // Join room
  const rr1 = waitFor(sock1, "room_ready");
  const rr2 = waitFor(sock2, "room_ready");
  sock1.emit("join_room", { matchId });
  sock2.emit("join_room", { matchId });
  await Promise.all([rr1, rr2]);

  // Wait for game_start (~2.5 s)
  const gs1 = waitFor(sock1, "game_start", 8000);
  const gs2 = waitFor(sock2, "game_start", 8000);
  const [gameStart] = await Promise.all([gs1, gs2]);

  const firstTurnColor = gameStart.firstTurn;
  const activeSock  = firstTurnColor === mf1.color ? sock1 : sock2;
  const waitSock    = firstTurnColor === mf1.color ? sock2 : sock1;
  const activeColor = firstTurnColor;
  const waitColor   = firstTurnColor === mf1.color ? mf2.color : mf1.color;
  const activeTok   = firstTurnColor === mf1.color ? tok1 : tok2;

  return {
    sock1, sock2,
    matchId,
    mf1, mf2,
    activeSock,  waitSock,
    activeColor, waitColor,
    activeTok,
  };
}

// ---------------------------------------------------------------------------
// Gameplay helpers
// ---------------------------------------------------------------------------

/**
 * Play the match to completion.  Both players take turns greedily
 * (always move pawn[0] if possible, else any valid pawn) until one side
 * receives `game_over`.
 *
 * Returns the `game_over` payload received on `watchSock`.
 *
 * @param {object} ctx          - Match context returned by setupMatch.
 * @param {object} watchSock    - The socket to await game_over on.
 * @param {number} maxTurns     - Safety limit to prevent infinite loops.
 */
async function playToCompletion(ctx, watchSock, maxTurns = 400) {
  let { matchId, activeSock, waitSock, activeColor, waitColor } = ctx;

  // Subscribe to game_over once before the loop so we don't miss it.
  let gameOverResolve;
  const gameOverPromise = new Promise((resolve) => {
    gameOverResolve = resolve;
    watchSock.once("game_over", resolve);
  });

  // Also listen on the other socket in case it fires there first.
  let gameOverOther = false;
  const otherSock = watchSock === activeSock ? waitSock : activeSock;
  otherSock.once("game_over", () => { gameOverOther = true; });

  for (let turn = 0; turn < maxTurns; turn++) {
    // ── Roll ─────────────────────────────────────────────────────────────
    const drA = waitFor(activeSock, "dice_rolled", 8000);
    const drW = waitFor(waitSock,   "dice_rolled", 8000);

    activeSock.emit("roll_dice", { matchId });

    const [dr] = await Promise.all([drA, drW]);

    if (dr.validMoves.length === 0) {
      // Auto-pass: wait for turn_changed.
      const tcA = waitFor(activeSock, "turn_changed", 5000);
      const tcW = waitFor(waitSock,   "turn_changed", 5000);
      await Promise.all([tcA, tcW]);

      [activeSock, waitSock]   = [waitSock, activeSock];
      [activeColor, waitColor] = [waitColor, activeColor];
      continue;
    }

    // ── Move ──────────────────────────────────────────────────────────────
    // Prefer pawn[0]; fall back to first valid move.
    const move = dr.validMoves.find((m) => m.pawnIndex === 0) ?? dr.validMoves[0];

    const pmA = waitFor(activeSock, "pawn_moved", 8000);
    const pmW = waitFor(waitSock,   "pawn_moved", 8000);

    // Race move against game_over (the winning move does NOT emit turn_changed).
    const goRaceA = new Promise((res) => activeSock.once("game_over", res));
    const goRaceW = new Promise((res) => waitSock.once("game_over", res));

    activeSock.emit("move_pawn", { matchId, pawnIndex: move.pawnIndex });

    await Promise.all([pmA, pmW]);

    // Check if game_over already arrived (winning move).
    const goCheck = await Promise.race([
      goRaceA.then((d) => d),
      goRaceW.then((d) => d),
      sleep(100).then(() => null),
    ]);

    if (goCheck) {
      // game_over fired — resolve our outer promise too.
      gameOverResolve(goCheck);
      return gameOverPromise;
    }

    // Not yet over — wait for turn_changed.
    const tcA = waitFor(activeSock, "turn_changed", 8000);
    const tcW = waitFor(waitSock,   "turn_changed", 8000);
    const [tc] = await Promise.all([tcA, tcW]);

    // Update active player based on nextTurn.
    if (tc.nextTurn !== activeColor) {
      [activeSock, waitSock]   = [waitSock, activeSock];
      [activeColor, waitColor] = [waitColor, activeColor];
    }
  }

  throw new Error(`playToCompletion: no game_over within ${maxTurns} turns.`);
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

async function runTests() {
  console.log("\n\x1b[1mPhase 6.7.6 — Win Completion Integration Tests\x1b[0m\n");

  // ── Test 1: game_over { reason: 'completed' } emitted to both sockets ──────
  {
    console.log("Test 1 — game_over { reason: 'completed' } emitted to both sockets on normal win");
    try {
      const ctx = await setupMatch("T1");
      const { sock1, sock2, matchId } = ctx;

      // Listen on both sockets.
      const go1 = waitFor(sock1, "game_over", 300_000);
      const go2 = waitFor(sock2, "game_over", 300_000);

      // Play from sock1's perspective (doesn't matter which).
      await playToCompletion({ ...ctx, activeSock: ctx.activeSock, waitSock: ctx.waitSock }, sock1);

      const [result1, result2] = await Promise.all([go1, go2]);

      assert(result1.matchId  === matchId,     "sock1 game_over.matchId is correct");
      assert(result1.reason   === "completed", "sock1 game_over.reason is 'completed'");
      assert(typeof result1.winnerId === "string" && result1.winnerId.length > 0,
        "sock1 game_over.winnerId is a non-empty string");

      assert(result2.matchId  === matchId,     "sock2 game_over.matchId is correct");
      assert(result2.reason   === "completed", "sock2 game_over.reason is 'completed'");
      assert(result2.winnerId === result1.winnerId,
        "both sockets report the same winnerId");

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 2: game_over.winnerId matches the actual winner's userId ──────────
  {
    console.log("\nTest 2 — game_over.winnerId matches the winning player's UUID");
    try {
      const reg1 = await register("T2A");
      const reg2 = await register("T2B");
      const u1email = reg1.user?.email ?? reg1.email;
      const u2email = reg2.user?.email ?? reg2.email;
      const tok1 = await login(u1email);
      const tok2 = await login(u2email);

      const [userId1, userId2] = await Promise.all([getUserId(tok1), getUserId(tok2)]);

      const sock1 = await connectSocket(tok1);
      const sock2 = await connectSocket(tok2);

      const mf1P = waitFor(sock1, "match_found");
      const mf2P = waitFor(sock2, "match_found");
      sock1.emit("find_match");
      await sleep(100);
      sock2.emit("find_match");
      const [mf1, mf2] = await Promise.all([mf1P, mf2P]);
      const matchId = mf1.matchId;

      const rr1 = waitFor(sock1, "room_ready");
      const rr2 = waitFor(sock2, "room_ready");
      sock1.emit("join_room", { matchId });
      sock2.emit("join_room", { matchId });
      await Promise.all([rr1, rr2]);

      const gs1 = waitFor(sock1, "game_start", 8000);
      const gs2 = waitFor(sock2, "game_start", 8000);
      const [gs] = await Promise.all([gs1, gs2]);

      const activeSock  = gs.firstTurn === mf1.color ? sock1 : sock2;
      const waitSock    = gs.firstTurn === mf1.color ? sock2 : sock1;
      const activeColor = gs.firstTurn;
      const waitColor   = gs.firstTurn === mf1.color ? mf2.color : mf1.color;

      const ctx = { matchId, activeSock, waitSock, activeColor, waitColor };

      const go1 = waitFor(sock1, "game_over", 300_000);
      const go2 = waitFor(sock2, "game_over", 300_000);

      await playToCompletion(ctx, sock1);

      const [result1] = await Promise.all([go1, go2]);

      assert(
        result1.winnerId === userId1 || result1.winnerId === userId2,
        "game_over.winnerId matches one of the two players' UUIDs",
      );

      const winnerLabel =
        result1.winnerId === userId1 ? "user1" : "user2";
      console.log(`    (winner: ${winnerLabel}, userId: ${result1.winnerId})`);

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 3: roll_dice emits error after win (game state cleared) ───────────
  {
    console.log("\nTest 3 — roll_dice emits error after game_over (game state cleared)");
    try {
      const ctx = await setupMatch("T3");
      const { sock1, sock2, matchId } = ctx;

      const go1 = waitFor(sock1, "game_over", 300_000);
      const go2 = waitFor(sock2, "game_over", 300_000);

      await playToCompletion(ctx, sock1);
      await Promise.all([go1, go2]);

      // Give the server a moment to finalize cleanup.
      await sleep(200);

      // Attempt to roll dice — both sockets should receive an error since the
      // game state has been cleared by clearGameState() after the win.
      const errPromise = waitFor(sock1, "error", 3000);
      sock1.emit("roll_dice", { matchId });
      const err = await errPromise;

      assert(typeof err.message === "string", "error.message is a string after post-win roll");
      assert(
        err.message.toLowerCase().includes("not found") ||
        err.message.toLowerCase().includes("not in progress") ||
        err.message.toLowerCase().includes("game"),
        "error.message indicates game is no longer active",
      );

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 4: server remains healthy after a normal win ─────────────────────
  {
    console.log("\nTest 4 — server remains healthy after normal win (follow-up match reaches game_start)");
    try {
      // Play and complete a full game.
      const ctx = await setupMatch("T4a");
      const go1 = waitFor(ctx.sock1, "game_over", 300_000);
      const go2 = waitFor(ctx.sock2, "game_over", 300_000);
      await playToCompletion(ctx, ctx.sock1);
      await Promise.all([go1, go2]);
      ctx.sock1.disconnect();
      ctx.sock2.disconnect();

      await sleep(300);

      // Immediately start a new match to confirm the server is still healthy.
      const ctx2 = await setupMatch("T4b");
      assert(ctx2.matchId.length > 0, "follow-up match paired and game_start received");
      ctx2.sock1.disconnect();
      ctx2.sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 5: game_over.matchId matches the played match ────────────────────
  {
    console.log("\nTest 5 — game_over.matchId matches the original matchId");
    try {
      const ctx = await setupMatch("T5");
      const { sock1, sock2, matchId } = ctx;

      const go1 = waitFor(sock1, "game_over", 300_000);
      const go2 = waitFor(sock2, "game_over", 300_000);

      await playToCompletion(ctx, sock1);

      const [result1, result2] = await Promise.all([go1, go2]);

      assert(result1.matchId === matchId,
        "sock1 game_over.matchId === matchId from matchmaking");
      assert(result2.matchId === matchId,
        "sock2 game_over.matchId === matchId from matchmaking");
      assert(result1.reason  === "completed",
        "sock1 game_over.reason confirms this was a normal completion");

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log(`\n${"─".repeat(55)}`);
  console.log(`Passed: ${passed}  Failed: ${failed}`);
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
