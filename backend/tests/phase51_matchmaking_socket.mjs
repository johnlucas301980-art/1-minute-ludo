#!/usr/bin/env node
/**
 * Phase 5.1 — Matchmaking Socket.IO Integration Tests
 *
 * Uses socket.io-client (devDependency) for reliable event testing.
 *
 * Run: node backend/tests/phase51_matchmaking_socket.mjs
 */

import { io } from 'socket.io-client';

const BASE = process.env.BASE_SOCKET ?? 'http://localhost:5000';
const API  = process.env.BASE        ?? 'http://localhost:5000/api';

let PASS = 0;
let FAIL = 0;

// ── Helpers ───────────────────────────────────────────────────────────────────

function assert(label, condition) {
  if (condition) {
    console.log(`  ✅ PASS: ${label}`);
    PASS++;
  } else {
    console.log(`  ❌ FAIL: ${label}`);
    FAIL++;
  }
}

function assertEq(label, expected, actual) {
  if (actual === expected) {
    console.log(`  ✅ PASS: ${label}`);
    PASS++;
  } else {
    console.log(`  ❌ FAIL: ${label} — expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
    FAIL++;
  }
}

// ── Auth helpers ──────────────────────────────────────────────────────────────

async function registerAndLogin(suffix) {
  const ts    = Date.now();
  const email = `matchsock${ts}${suffix}@example.com`;
  const pass  = 'MatchPass123';

  await fetch(`${API}/auth/register`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify({ full_name: `Socket Tester ${suffix}`, email, password: pass }),
  });

  const res  = await fetch(`${API}/auth/login`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify({ identifier: email, password: pass }),
  });
  const data = await res.json();
  return data?.data?.access_token ?? null;
}

// ── Socket helpers ────────────────────────────────────────────────────────────

/**
 * Create a socket.io-client connection with the given auth token.
 * Returns a Promise that resolves with { socket, connectError } where
 * connectError is null on success or an Error on failure.
 */
function createSocket(token, timeoutMs = 5000) {
  return new Promise((resolve) => {
    const socket = io(BASE, {
      auth: { token: token ?? '' },
      transports: ['polling'],
      reconnection: false,
      timeout: timeoutMs,
    });

    const timer = setTimeout(() => {
      socket.disconnect();
      resolve({ socket, connectError: new Error('Connection timed out') });
    }, timeoutMs);

    socket.once('connect', () => {
      clearTimeout(timer);
      resolve({ socket, connectError: null });
    });

    socket.once('connect_error', (err) => {
      clearTimeout(timer);
      resolve({ socket, connectError: err });
    });
  });
}

/**
 * Wait for a specific event on a socket, with a timeout.
 * Returns the event data or null on timeout.
 */
function waitForEvent(socket, event, timeoutMs = 5000) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), timeoutMs);
    socket.once(event, (data) => {
      clearTimeout(timer);
      resolve(data);
    });
  });
}

/** Disconnect a socket cleanly. */
function closeSocket(socket) {
  if (socket && socket.connected) {
    socket.disconnect();
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('');
  console.log('═══════════════════════════════════════════════════');
  console.log('  PHASE 5.1 — Socket.IO Matchmaking Integration Tests');
  console.log('═══════════════════════════════════════════════════');

  // ── 1. Unauthorized connections ───────────────────────────────────────────

  console.log('\n── 1. Unauthorized connections (no / bad token) ─────');

  {
    const { socket, connectError } = await createSocket('');
    assert('Empty token → connect_error', connectError !== null);
    assert('Empty token → socket not connected', !socket.connected);
    closeSocket(socket);
  }

  {
    const { socket, connectError } = await createSocket('invalid.jwt.token');
    assert('Invalid JWT → connect_error', connectError !== null);
    assert('Invalid JWT → socket not connected', !socket.connected);
    closeSocket(socket);
  }

  // ── 2. Obtain tokens for two test users ──────────────────────────────────

  console.log('\n── 2. Setup: register two players ───────────────────');
  const token1 = await registerAndLogin('A');
  const token2 = await registerAndLogin('B');
  assert('Player 1 token obtained', typeof token1 === 'string' && token1.length > 0);
  assert('Player 2 token obtained', typeof token2 === 'string' && token2.length > 0);

  // ── 3. Authenticated connection ───────────────────────────────────────────

  console.log('\n── 3. Authenticated connection ──────────────────────');
  {
    const { socket, connectError } = await createSocket(token1);
    assert('Valid token → no connect_error', connectError === null);
    assert('Valid token → socket connected', socket.connected);
    closeSocket(socket);
  }

  // ── 4. Single player joins queue (queue_joined) ───────────────────────────

  console.log('\n── 4. Single player joins queue → queue_joined ──────');
  {
    const { socket } = await createSocket(token1);
    assert('Socket connected for test 4', socket.connected);

    socket.emit('find_match');
    const data = await waitForEvent(socket, 'queue_joined', 5000);

    assert('find_match → queue_joined received', data !== null);
    assert('queue_joined has queueSize field', data !== null && typeof data.queueSize === 'number');
    assert('queueSize >= 1 after joining',      data !== null && data.queueSize >= 1);

    // Leave so the queue is clean for next tests
    socket.emit('leave_queue');
    await waitForEvent(socket, 'queue_left', 3000);
    closeSocket(socket);
  }

  // ── 5. Leave queue ────────────────────────────────────────────────────────

  console.log('\n── 5. Leave queue → queue_left ──────────────────────');
  {
    const { socket } = await createSocket(token1);
    socket.emit('find_match');
    await waitForEvent(socket, 'queue_joined', 3000);

    socket.emit('leave_queue');
    const data = await waitForEvent(socket, 'queue_left', 3000);

    assert('leave_queue → queue_left received', data !== null);
    assert('queue_left has success:true', data !== null && data.success === true);
    closeSocket(socket);
  }

  // ── 6. Leave queue (idempotent — not in queue) ───────────────────────────

  console.log('\n── 6. Leave queue (idempotent, not queued) ──────────');
  {
    const { socket } = await createSocket(token1);
    // Do NOT emit find_match first
    socket.emit('leave_queue');
    const data = await waitForEvent(socket, 'queue_left', 3000);
    assert('leave_queue while not queued → queue_left (idempotent)', data !== null);
    closeSocket(socket);
  }

  // ── 7. Two players — match_found ──────────────────────────────────────────

  console.log('\n── 7. Two players paired → match_found ──────────────');
  {
    // Player 1 joins first and waits
    const { socket: s1 } = await createSocket(token1);
    s1.emit('find_match');
    const p1Joined = await waitForEvent(s1, 'queue_joined', 5000);
    assert('Player 1: queue_joined received', p1Joined !== null);

    // Set up listener for Player 1's match_found BEFORE Player 2 joins
    const p1MatchPromise = waitForEvent(s1, 'match_found', 8000);

    // Player 2 joins — triggers pairing
    const { socket: s2 } = await createSocket(token2);
    s2.emit('find_match');

    // Player 2 gets match_found (they trigger pairing)
    const p2Match = await waitForEvent(s2, 'match_found', 8000);
    // Player 1 also gets match_found (emitted to their socketId)
    const p1Match = await p1MatchPromise;

    assert('Player 2: match_found received', p2Match !== null);
    assert('Player 1: match_found received', p1Match !== null);

    // ── Validate match_found payload ─────────────────────────────────────────

    if (p2Match) {
      assert('match_found has matchId (non-empty string)',
        typeof p2Match.matchId === 'string' && p2Match.matchId.length > 0);
      assert('match_found has roomCode (6 chars)',
        typeof p2Match.roomCode === 'string' && p2Match.roomCode.length === 6);
      assert('match_found has valid color',
        ['red', 'blue', 'green', 'yellow'].includes(p2Match.color));
      assert('match_found has opponent object',
        p2Match.opponent !== null && typeof p2Match.opponent === 'object');
      assert('opponent has playerId (string)',
        typeof p2Match.opponent?.playerId === 'string');
      assert('opponent has fullName (string)',
        typeof p2Match.opponent?.fullName === 'string');
      assert('opponent.avatar is string or null',
        p2Match.opponent?.avatar === null || typeof p2Match.opponent?.avatar === 'string');
    }

    if (p1Match && p2Match) {
      assertEq('Both players share the same matchId',
        p1Match.matchId, p2Match.matchId);
      assertEq('Both players share the same roomCode',
        p1Match.roomCode, p2Match.roomCode);
      assert('Players receive different colors',
        p1Match.color !== p2Match.color);
    }

    closeSocket(s1);
    closeSocket(s2);
  }

  // ── 8. Duplicate find_match on same socket (idempotent) ───────────────────

  console.log('\n── 8. Duplicate find_match (idempotent) ─────────────');
  {
    const { socket } = await createSocket(token1);
    socket.emit('find_match');
    const j1 = await waitForEvent(socket, 'queue_joined', 3000);
    assert('First find_match: queue_joined', j1 !== null);

    socket.emit('find_match');
    const j2 = await waitForEvent(socket, 'queue_joined', 3000);
    assert('Second find_match (same socket): queue_joined (updated)', j2 !== null);

    socket.emit('leave_queue');
    await waitForEvent(socket, 'queue_left', 3000);
    closeSocket(socket);
  }

  // ── 9. Disconnect removes player from queue ───────────────────────────────

  console.log('\n── 9. Disconnect removes player from queue ──────────');
  {
    const { socket } = await createSocket(token1);
    socket.emit('find_match');
    await waitForEvent(socket, 'queue_joined', 3000);

    // Disconnect without leaving
    closeSocket(socket);
    // Give the server a moment to process the disconnect
    await new Promise(r => setTimeout(r, 500));

    // Check via REST that the player is no longer in queue
    // (We need a fresh token — use a fresh login for the REST check)
    const statusRes = await fetch(`${API}/match/queue/status`, {
      headers: { 'Authorization': `Bearer ${token1}` },
    });
    const statusData = await statusRes.json();
    assert('After disconnect: player not in queue (REST status)', statusData?.data?.inQueue === false);
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  console.log('');
  console.log('═══════════════════════════════════════════════════');
  console.log(`  Socket Results: PASS=${PASS}  FAIL=${FAIL}`);
  console.log('═══════════════════════════════════════════════════');
  console.log('');

  if (FAIL > 0) process.exit(1);
}

main().catch(err => {
  console.error('FATAL:', err);
  process.exit(1);
});
