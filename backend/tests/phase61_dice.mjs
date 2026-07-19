/**
 * Phase 6.1 — Ludo Game Engine: roll_dice integration tests.
 *
 * Requires a running backend with a connected PostgreSQL database.
 * Two socket clients simulate two matched players progressing from
 * matchmaking → room join → game_start → roll_dice.
 *
 * Run:
 *   node backend/tests/phase61_dice.mjs
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
    full_name: `Phase61 User ${suffix}`,
    email:     `phase61_${suffix}_${Date.now()}@test.invalid`,
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
// Setup — register two users, connect their sockets, reach game_start
// ---------------------------------------------------------------------------

async function setupMatch() {
  const reg1 = await register("A");
  const reg2 = await register("B");

  const u1email = reg1.user?.email ?? reg1.email;
  const u2email = reg2.user?.email ?? reg2.email;

  const access1 = await login(u1email);
  const access2 = await login(u2email);

  if (!access1 || !access2) {
    throw new Error("Login failed — check backend is running with valid JWT secrets.");
  }

  const sock1 = await connectSocket(access1);
  const sock2 = await connectSocket(access2);

  // Match-making
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

  // Both join the room
  const rr1 = waitFor(sock1, "room_ready");
  const rr2 = waitFor(sock2, "room_ready");
  sock1.emit("join_room", { matchId });
  sock2.emit("join_room", { matchId });
  await Promise.all([rr1, rr2]);

  // Wait for game_start (~2.5 s)
  const gs1 = waitFor(sock1, "game_start", 6000);
  const gs2 = waitFor(sock2, "game_start", 6000);
  const [gameStart1, gameStart2] = await Promise.all([gs1, gs2]);

  // Determine which socket holds the first turn
  const currentTurnSock = gameStart1.firstTurn === mf1.color ? sock1 : sock2;
  const waitingTurnSock = gameStart1.firstTurn === mf1.color ? sock2 : sock1;
  const currentTurnColor = gameStart1.firstTurn;
  const waitingTurnColor = gameStart1.firstTurn === mf1.color ? mf2.color : mf1.color;

  return {
    sock1, sock2,
    matchId,
    gameStart1, gameStart2,
    mf1, mf2,
    currentTurnSock,  // socket whose colour matches firstTurn
    waitingTurnSock,  // socket that must wait
    currentTurnColor,
    waitingTurnColor,
  };
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

async function runTests() {
  console.log("\n\x1b[1mPhase 6.1 — Ludo Game Engine: roll_dice\x1b[0m\n");

  // ── Test 1: dice_rolled emitted to both sockets with valid payload ─────────
  {
    console.log("Test 1 — dice_rolled emitted to both sockets with valid payload");
    try {
      const { sock1, sock2, matchId, currentTurnSock, currentTurnColor } =
        await setupMatch();

      // Both sockets listen for dice_rolled
      const dr1 = waitFor(sock1, "dice_rolled");
      const dr2 = waitFor(sock2, "dice_rolled");

      currentTurnSock.emit("roll_dice", { matchId });

      const [r1, r2] = await Promise.all([dr1, dr2]);

      // Both receive the same event
      assert(r1.matchId === matchId,           "dice_rolled.matchId correct on rolling socket");
      assert(r1.color   === currentTurnColor,  "dice_rolled.color matches firstTurn colour");
      assert(typeof r1.value === "number" &&
             r1.value >= 1 && r1.value <= 6,   "dice_rolled.value is a number between 1 and 6");
      assert(Array.isArray(r1.validMoves),      "dice_rolled.validMoves is an array");

      assert(r2.matchId === matchId,            "dice_rolled.matchId correct on waiting socket");
      assert(r2.color   === r1.color,           "dice_rolled.color identical on both sockets");
      assert(r2.value   === r1.value,           "dice_rolled.value identical on both sockets");

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 2: roll_dice without matchId emits error ─────────────────────────
  {
    console.log("\nTest 2 — roll_dice without matchId emits error");
    try {
      const { sock1, sock2, currentTurnSock } = await setupMatch();

      const errPromise = waitFor(currentTurnSock, "error");
      currentTurnSock.emit("roll_dice", {}); // missing matchId

      const err = await errPromise;

      assert(typeof err.message === "string",              "error.message is a string");
      assert(err.message.toLowerCase().includes("matchid") ||
             err.message.toLowerCase().includes("required") ||
             err.message.toLowerCase().includes("roll"),
        "error.message mentions matchId or requirement");

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 3: wrong-turn player rolls → error ────────────────────────────────
  {
    console.log("\nTest 3 — non-turn player rolling emits 'It is not your turn' error");
    try {
      const { sock1, sock2, matchId, waitingTurnSock } = await setupMatch();

      const errPromise = waitFor(waitingTurnSock, "error");
      waitingTurnSock.emit("roll_dice", { matchId });

      const err = await errPromise;

      assert(typeof err.message === "string",       "error.message is a string");
      assert(err.message.toLowerCase().includes("turn"),
        "error.message mentions 'turn'");

      sock1.disconnect();
      sock2.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 4: non-participant socket emits error ─────────────────────────────
  {
    console.log("\nTest 4 — non-participant socket emits error on roll_dice");
    try {
      const { sock1, sock2, matchId } = await setupMatch();

      // Register and connect a third user unrelated to this match
      const reg3    = await register("C");
      const u3email = reg3.user?.email ?? reg3.email;
      const tok3    = await login(u3email);
      const sock3   = await connectSocket(tok3);

      const errPromise = waitFor(sock3, "error");
      sock3.emit("roll_dice", { matchId });

      const err = await errPromise;

      assert(typeof err.message === "string", "non-participant receives error event");

      sock1.disconnect();
      sock2.disconnect();
      sock3.disconnect();
    } catch (err) {
      console.error(`  ${FAIL}  Error: ${err.message}`);
      failed++;
    }
  }

  // ── Test 5: turn passing & phase enforcement ──────────────────────────────
  //
  // With all 4 pawns in the yard (position 0):
  //   - dice ≠ 6  → validMoves is empty  → turn_changed fires automatically
  //   - dice = 6  → validMoves has 4 entries → phase = waiting_move;
  //                  rolling again immediately emits an error
  //
  // We test both branches and assert whichever applies.
  {
    console.log("\nTest 5 — phase transition: no-valid-moves passes turn / valid-moves blocks re-roll");
    try {
      const { sock1, sock2, matchId, currentTurnSock, waitingTurnSock,
              currentTurnColor, waitingTurnColor } = await setupMatch();

      // Listen on both sockets for dice_rolled
      const drSelf     = waitFor(currentTurnSock, "dice_rolled");
      const drOpponent = waitFor(waitingTurnSock, "dice_rolled");

      // Set up a race: turn_changed fires if no valid moves; error fires if
      // we try to re-roll while in waiting_move phase.
      const tcSelf     = waitFor(currentTurnSock, "turn_changed", 3000).catch(() => null);
      const tcOpponent = waitFor(waitingTurnSock, "turn_changed", 3000).catch(() => null);

      currentTurnSock.emit("roll_dice", { matchId });

      const drResult = await drSelf;
      await drOpponent; // drain event from waiting socket

      assert(Array.isArray(drResult.validMoves), "dice_rolled.validMoves is always an array");

      if (drResult.validMoves.length === 0) {
        // ── Branch A: dice ≠ 6 — no valid moves — turn_changed must fire ─────
        const [tc1, tc2] = await Promise.all([tcSelf, tcOpponent]);

        assert(tc1 !== null,                             "turn_changed fires on current-turn socket when no valid moves");
        assert(tc2 !== null,                             "turn_changed fires on waiting-turn socket when no valid moves");
        assert(tc1?.nextTurn === waitingTurnColor,       "turn_changed.nextTurn is opponent's colour");
        assert(tc1?.matchId  === matchId,                "turn_changed.matchId is correct");
        assert(tc1?.nextTurn === tc2?.nextTurn,          "both sockets receive same nextTurn");

      } else {
        // ── Branch B: dice = 6 — valid moves exist — phase = waiting_move ────
        // Each valid move must reference a pawn in the yard (fromPos 0 → toPos 1).
        for (const move of drResult.validMoves) {
          assert(move.pawnIndex >= 0 && move.pawnIndex <= 3, `validMove.pawnIndex ${move.pawnIndex} in range 0–3`);
          assert(move.fromPos === 0,  `validMove.fromPos is 0 (yard) for dice=6`);
          assert(move.toPos   === 1,  `validMove.toPos is 1 (entry square) for dice=6`);
        }

        // Rolling again in waiting_move phase must produce an error
        const reRollError = waitFor(currentTurnSock, "error", 3000);
        currentTurnSock.emit("roll_dice", { matchId });
        const err = await reRollError;

        assert(typeof err.message === "string",           "re-rolling in waiting_move emits error");
        assert(err.message.toLowerCase().includes("move") ||
               err.message.toLowerCase().includes("pawn") ||
               err.message.toLowerCase().includes("roll"),
          "re-roll error message mentions move/pawn/roll");
      }

      sock1.disconnect();
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
