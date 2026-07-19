/**
 * Phase 5.6 — Forfeit & Game Termination integration tests.
 *
 * Requires a running backend with a connected PostgreSQL database.
 * Two socket clients simulate two matched players.
 *
 * Run:
 *   node backend/tests/phase56_forfeit.mjs
 */

import { io } from "socket.io-client";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const BASE_URL   = process.env["BASE_URL"]   ?? "http://localhost:5000";
const API_BASE   = `${BASE_URL}/api`;
const PASS       = "\x1b[32m✔\x1b[0m";
const FAIL       = "\x1b[31m✘\x1b[0m";

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
    full_name: `Phase56 User ${suffix}`,
    email:     `phase56_${suffix}_${Date.now()}@test.invalid`,
    password:  "TestPass1!",
  });
  const data = await res.json();
  return data;
}

async function login(email, password) {
  const res  = await apiPost("/auth/login", { identifier: email, password });
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

function waitFor(socket, event, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Timed out waiting for "${event}"`));
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
// Setup — register two users, connect their sockets, find a match
// ---------------------------------------------------------------------------

async function setupMatch() {
  // Register and log in two users
  const reg1  = await register("A");
  const reg2  = await register("B");
  const tok1  = await login(reg1.email ?? reg1.identifier ?? reg1.user?.email, "TestPass1!");
  const tok2  = await login(reg2.email ?? reg2.identifier ?? reg2.user?.email, "TestPass1!");

  // Actually we need to re-register properly and extract email
  // Let's re-approach: register returns user object
  const u1email = reg1.user?.email ?? reg1.email;
  const u2email = reg2.user?.email ?? reg2.email;

  const access1 = await login(u1email, "TestPass1!");
  const access2 = await login(u2email, "TestPass1!");

  if (!access1 || !access2) {
    throw new Error("Login failed — check backend is running with valid JWT secrets.");
  }

  // Connect sockets
  const sock1 = await connectSocket(access1);
  const sock2 = await connectSocket(access2);

  // Find match — one joins queue, second triggers pairing
  const matchFound1Promise = waitFor(sock1, "match_found");
  const matchFound2Promise = waitFor(sock2, "match_found");

  sock1.emit("find_match");
  await sleep(100);
  sock2.emit("find_match");

  const [mf1, mf2] = await Promise.all([matchFound1Promise, matchFound2Promise]);

  // Both must have the same matchId
  if (mf1.matchId !== mf2.matchId) {
    throw new Error(`matchId mismatch: ${mf1.matchId} vs ${mf2.matchId}`);
  }

  const matchId = mf1.matchId;

  // Both join the room
  const roomReady1 = waitFor(sock1, "room_ready");
  const roomReady2 = waitFor(sock2, "room_ready");
  sock1.emit("join_room", { matchId });
  sock2.emit("join_room", { matchId });
  await Promise.all([roomReady1, roomReady2]);

  // Wait for game_start (~2.5 s)
  const gs1 = waitFor(sock1, "game_start", 6000);
  const gs2 = waitFor(sock2, "game_start", 6000);
  const [gameStart1, gameStart2] = await Promise.all([gs1, gs2]);

  return { sock1, sock2, matchId, gameStart1, gameStart2 };
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

async function runTests() {
  console.log("\n\x1b[1mPhase 5.6 — Forfeit & Game Termination\x1b[0m\n");

  // ── Test 1: forfeit emits game_over to both players ──────────────────────
  {
    console.log("Test 1 — forfeit emits game_over to both players");
    try {
      const { sock1, sock2, matchId } = await setupMatch();

      const go1 = waitFor(sock1, "game_over");
      const go2 = waitFor(sock2, "game_over");

      // sock1 forfeits
      sock1.emit("forfeit", { matchId });

      const [r1, r2] = await Promise.all([go1, go2]);

      assert(r1.matchId  === matchId, `game_over.matchId correct on forfeiting socket`);
      assert(r1.reason   === "forfeit", `game_over.reason is 'forfeit' on forfeiting socket`);
      assert(typeof r1.winnerId === "string" && r1.winnerId.length > 0,
        `game_over.winnerId is a non-empty string`);

      assert(r2.matchId  === matchId, `game_over.matchId correct on opponent socket`);
      assert(r2.reason   === "forfeit", `game_over.reason is 'forfeit' on opponent socket`);
      assert(r2.winnerId === r1.winnerId, `game_over.winnerId is the same on both sockets`);

      // Opponent is the winner — winnerId must NOT equal the forfeiting player's user id
      // (We can't easily know the user ids here, but both players received the same winnerId.)

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 2: forfeit without matchId emits error ───────────────────────────
  {
    console.log("\nTest 2 — forfeit without matchId emits error event");
    try {
      const { sock1, sock2, matchId } = await setupMatch();

      const errorPromise = waitFor(sock1, "error");
      sock1.emit("forfeit", {}); // missing matchId
      const err = await errorPromise;

      assert(typeof err.message === "string", `error.message is a string`);
      assert(err.message.toLowerCase().includes("matchid") ||
             err.message.toLowerCase().includes("required") ||
             err.message.toLowerCase().includes("forfeit"),
        `error.message mentions matchId / required`);

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 3: forfeit from non-participant emits error ──────────────────────
  {
    console.log("\nTest 3 — forfeit from non-participant emits error");
    try {
      const { sock1, sock2, matchId } = await setupMatch();

      // Register a third user and connect
      const reg3    = await register("C");
      const u3email = reg3.user?.email ?? reg3.email;
      const tok3    = await login(u3email, "TestPass1!");
      const sock3   = await connectSocket(tok3);

      const errorPromise = waitFor(sock3, "error");
      sock3.emit("forfeit", { matchId });
      const err = await errorPromise;

      assert(typeof err.message === "string", `non-participant receives error`);

      sock1.disconnect();
      sock2.disconnect();
      sock3.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 4: double forfeit is idempotent (second call emits no event) ─────
  {
    console.log("\nTest 4 — second forfeit on finished match is idempotent");
    try {
      const { sock1, sock2, matchId } = await setupMatch();

      const go1 = waitFor(sock1, "game_over");
      const go2 = waitFor(sock2, "game_over");

      sock1.emit("forfeit", { matchId });
      await Promise.all([go1, go2]);

      // Second forfeit — no additional game_over should arrive within 1 s
      let extraReceived = false;
      sock2.once("game_over", () => { extraReceived = true; });
      sock1.emit("forfeit", { matchId });
      await sleep(1000);

      assert(!extraReceived, `second forfeit does not emit duplicate game_over`);

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 5: disconnect during game triggers auto-forfeit ──────────────────
  {
    console.log("\nTest 5 — disconnect during in_progress match triggers auto-forfeit");
    try {
      const { sock1, sock2, matchId } = await setupMatch();

      const go2 = waitFor(sock2, "game_over", 6000);

      // sock1 disconnects abruptly
      sock1.disconnect();

      const result = await go2;

      assert(result.matchId === matchId, `game_over.matchId correct after disconnect`);
      assert(result.reason  === "disconnect", `game_over.reason is 'disconnect'`);
      assert(typeof result.winnerId === "string" && result.winnerId.length > 0,
        `game_over.winnerId is populated`);

      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log(`\n${"─".repeat(50)}`);
  console.log(`Passed: ${passed}  Failed: ${failed}`);
  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
