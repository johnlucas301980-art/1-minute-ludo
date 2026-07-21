/**
 * Phase 6.7.4 — Pending Game Start Disconnect Protection.
 *
 * Tests the race-condition fix for players who disconnect after `room_ready`
 * but before `game_start` (the 2.5-second delay window).
 *
 * Requires a running backend with a connected PostgreSQL database.
 *
 * Run:
 *   node backend/tests/phase674_pending_disconnect.mjs
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
  const res  = await apiPost("/auth/register", {
    full_name: `Phase674 User ${suffix}`,
    email:     `phase674_${suffix}_${Date.now()}@test.invalid`,
    password:  "TestPass1!",
  });
  return res.json();
}

async function login(email) {
  const res  = await apiPost("/auth/login", { identifier: email, password: "TestPass1!" });
  const data = await res.json();
  return data.access_token;
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

/**
 * Register two users, connect sockets, find a match, have both join the room,
 * and wait for room_ready.  Does NOT wait for game_start — tests that need
 * the pending window stop here.
 */
async function setupUntilRoomReady(suffix) {
  const reg1 = await register(`${suffix}A`);
  const reg2 = await register(`${suffix}B`);

  const u1email = reg1.user?.email ?? reg1.email;
  const u2email = reg2.user?.email ?? reg2.email;

  const tok1 = await login(u1email);
  const tok2 = await login(u2email);

  if (!tok1 || !tok2) {
    throw new Error("Login failed — check backend is running.");
  }

  const sock1 = await connectSocket(tok1);
  const sock2 = await connectSocket(tok2);

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

  const rr1 = waitFor(sock1, "room_ready");
  const rr2 = waitFor(sock2, "room_ready");
  sock1.emit("join_room", { matchId });
  sock2.emit("join_room", { matchId });
  await Promise.all([rr1, rr2]);

  return { sock1, sock2, matchId };
}

/**
 * Full setup including game_start — used for tests that need an active game.
 */
async function setupUntilGameStart(suffix) {
  const { sock1, sock2, matchId } = await setupUntilRoomReady(suffix);

  const gs1 = waitFor(sock1, "game_start", 8000);
  const gs2 = waitFor(sock2, "game_start", 8000);
  const [gameStart1] = await Promise.all([gs1, gs2]);

  return { sock1, sock2, matchId, gameStart1 };
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

async function runTests() {
  console.log(
    "\n\x1b[1mPhase 6.7.4 — Pending Game Start Disconnect Protection\x1b[0m\n",
  );

  // ── Test 1: disconnect in the 2.5-second window ───────────────────────────
  {
    console.log(
      "Test 1 — disconnect after room_ready but before game_start: remaining player receives game_over",
    );
    try {
      const { sock1, sock2, matchId } = await setupUntilRoomReady("T1");

      // Listen for game_over on the remaining socket BEFORE disconnecting
      const go2 = waitFor(sock2, "game_over", 8000);

      // Immediately disconnect sock1 — this is within the 2.5 s pending window
      sock1.disconnect();

      const result = await go2;

      assert(result.matchId === matchId, `game_over.matchId matches`);
      assert(result.reason  === "disconnect", `game_over.reason is 'disconnect'`);
      assert(
        typeof result.winnerId === "string" && result.winnerId.length > 0,
        `game_over.winnerId is a non-empty string`,
      );

      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 2: game_over is NOT emitted after normal game_start ──────────────
  {
    console.log(
      "\nTest 2 — no premature game_over when game_start fires normally",
    );
    try {
      const { sock1, sock2 } = await setupUntilGameStart("T2");

      // After game_start both sockets should NOT receive game_over yet
      let prematureGameOver = false;
      sock1.once("game_over", () => { prematureGameOver = true; });
      sock2.once("game_over", () => { prematureGameOver = true; });

      // Wait 500 ms — game_over must NOT have arrived
      await sleep(500);

      assert(!prematureGameOver, `no premature game_over after normal game_start`);

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 3: pending entry cleaned up after normal game_start ─────────────
  {
    console.log(
      "\nTest 3 — after normal game_start, disconnect triggers active-game forfeit (not duplicate pending cleanup)",
    );
    try {
      const { sock1, sock2, matchId } = await setupUntilGameStart("T3");

      // Now disconnect sock1 — should trigger in_progress auto-forfeit
      const go2 = waitFor(sock2, "game_over", 6000);
      sock1.disconnect();
      const result = await go2;

      // Reason should be 'disconnect' from the active-game path, not a double event
      assert(result.matchId === matchId, `game_over.matchId correct after game_start`);
      assert(result.reason  === "disconnect", `game_over.reason is 'disconnect'`);

      // Verify no second game_over arrives within 500 ms (idempotency)
      let extra = false;
      sock2.once("game_over", () => { extra = true; });
      await sleep(500);
      assert(!extra, `no duplicate game_over received`);

      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 4: both players disconnect in the 2.5-second window ─────────────
  {
    console.log(
      "\nTest 4 — both players disconnect in the pending window: no crash, no orphan",
    );
    try {
      const { sock1, sock2 } = await setupUntilRoomReady("T4");

      // Disconnect both — neither can receive game_over.
      // Verify server does not crash by successfully running another match.
      sock1.disconnect();
      sock2.disconnect();

      // Allow the server to process both disconnects
      await sleep(500);

      // Verify the server is still healthy by running a new match that reaches game_start
      const { sock3, sock4 } = await (async () => {
        const reg3 = await register("T4C");
        const reg4 = await register("T4D");
        const e3   = reg3.user?.email ?? reg3.email;
        const e4   = reg4.user?.email ?? reg4.email;
        const t3   = await login(e3);
        const t4   = await login(e4);
        const s3   = await connectSocket(t3);
        const s4   = await connectSocket(t4);
        return { sock3: s3, sock4: s4 };
      })();

      const mf3 = waitFor(sock3, "match_found");
      const mf4 = waitFor(sock4, "match_found");
      sock3.emit("find_match");
      await sleep(100);
      sock4.emit("find_match");
      const [m3, m4] = await Promise.all([mf3, mf4]);

      assert(m3.matchId === m4.matchId, `follow-up match paired correctly after both-disconnect cleanup`);

      const rr3 = waitFor(sock3, "room_ready");
      const rr4 = waitFor(sock4, "room_ready");
      sock3.emit("join_room", { matchId: m3.matchId });
      sock4.emit("join_room", { matchId: m3.matchId });
      await Promise.all([rr3, rr4]);

      const gs3 = waitFor(sock3, "game_start", 8000);
      const gs4 = waitFor(sock4, "game_start", 8000);
      const [gs] = await Promise.all([gs3, gs4]);

      assert(gs.matchId === m3.matchId, `follow-up game_start fires correctly`);

      sock3.disconnect();
      sock4.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 5: pending disconnect winner is the remaining player ─────────────
  {
    console.log(
      "\nTest 5 — game_over.winnerId in pending-window disconnect matches remaining player",
    );
    try {
      const reg1 = await register("T5A");
      const reg2 = await register("T5B");
      const e1   = reg1.user?.email ?? reg1.email;
      const e2   = reg2.user?.email ?? reg2.email;
      const t1   = await login(e1);
      const t2   = await login(e2);

      const userId2Res = await (async () => {
        const res = await fetch(`${API_BASE}/profile`, {
          headers: { Authorization: `Bearer ${t2}` },
        });
        const body = await res.json();
        return body.data?.profile?.id ?? null;
      })();

      const sock1 = await connectSocket(t1);
      const sock2 = await connectSocket(t2);

      const mf1 = waitFor(sock1, "match_found");
      const mf2 = waitFor(sock2, "match_found");
      sock1.emit("find_match");
      await sleep(100);
      sock2.emit("find_match");
      const [m1] = await Promise.all([mf1, mf2]);

      const rr1 = waitFor(sock1, "room_ready");
      const rr2 = waitFor(sock2, "room_ready");
      sock1.emit("join_room", { matchId: m1.matchId });
      sock2.emit("join_room", { matchId: m1.matchId });
      await Promise.all([rr1, rr2]);

      // sock1 disconnects → sock2 must be declared winner
      const go2 = waitFor(sock2, "game_over", 8000);
      sock1.disconnect();
      const result = await go2;

      if (userId2Res) {
        assert(
          result.winnerId === userId2Res,
          `game_over.winnerId equals remaining player's userId`,
        );
      } else {
        assert(
          typeof result.winnerId === "string" && result.winnerId.length > 0,
          `game_over.winnerId is a non-empty string (profile fetch skipped)`,
        );
      }

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
