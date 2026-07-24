/**
 * Phase 9.2 — realtime notification delivery integration test.
 *
 * Requires:
 *   - a running backend
 *   - DATABASE_URL
 *   - migration 0011 applied
 *
 * Run:
 *   node backend/tests/phase92_notifications_realtime.mjs
 */

import pg from "pg";
import { io } from "socket.io-client";

const { Pool } = pg;
const BASE_URL = process.env["BASE_URL"] ?? "http://localhost:5000";
const API_BASE = `${BASE_URL}/api`;
const PASSWORD = "Phase92RealtimePass123!";
const database = new Pool({ connectionString: process.env["DATABASE_URL"] });

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✔ ${message}`);
    passed++;
  } else {
    console.error(`  ✘ ${message}`);
    failed++;
  }
}

async function api(path, options = {}) {
  return fetch(`${API_BASE}${path}`, options);
}

async function registerAndLogin(label) {
  const email = `phase92_${label}_${Date.now()}@test.invalid`;
  const register = await api("/auth/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      full_name: `Phase 9.2 ${label}`,
      email,
      password: PASSWORD,
    }),
  });
  if (!register.ok) {
    throw new Error(`Registration failed: ${await register.text()}`);
  }

  const login = await api("/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identifier: email, password: PASSWORD }),
  });
  const body = await login.json();
  if (!login.ok || !body.data?.access_token || !body.data?.profile?.id) {
    throw new Error(`Login failed: ${JSON.stringify(body)}`);
  }
  return {
    token: body.data.access_token,
    userId: body.data.profile.id,
  };
}

function connect(token) {
  return new Promise((resolve, reject) => {
    const socket = io(BASE_URL, {
      auth: { token },
      transports: ["websocket"],
      reconnection: false,
    });
    socket.once("connect", () => resolve(socket));
    socket.once("connect_error", reject);
  });
}

function waitFor(socket, event, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`Timed out waiting for ${event}`)),
      timeoutMs,
    );
    socket.once(event, (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

function waitForOptional(socket, event, timeoutMs = 750) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), timeoutMs);
    socket.once(event, (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

async function insertNotification(userId, suffix) {
  const result = await database.query(
    `INSERT INTO notifications
       (user_id, type, title, message, related_type, event_key)
     VALUES ($1, 'system', $2, $3, 'system', $4)
     RETURNING id`,
    [
      userId,
      `Realtime ${suffix}`,
      `Realtime notification ${suffix}.`,
      `phase92:${Date.now()}:${suffix}`,
    ],
  );
  return result.rows[0].id;
}

try {
  console.log("\nPhase 9.2 — Realtime Notification Delivery\n");
  const userA = await registerAndLogin("a");
  const userB = await registerAndLogin("b");
  const socketA = await connect(userA.token);
  const socketB = await connect(userB.token);

  console.log("1. User-specific delivery");
  const notificationA = waitFor(socketA, "notification_new");
  const unexpectedB = waitForOptional(socketB, "notification_new");
  const idA = await insertNotification(userA.userId, "a");
  const payloadA = await notificationA;
  const payloadB = await unexpectedB;

  assert(payloadA?.notification?.id === idA, "User A receives persisted notification");
  assert(payloadA?.notification?.type === "system", "Payload exposes notification fields");
  assert(payloadA?.notification?.user_id === undefined, "Payload omits user_id");
  assert(payloadA?.notification?.event_key === undefined, "Payload omits event_key");
  assert(payloadA?.unread_count === 1, "New notification includes unread count");
  assert(payloadB === null, "User B does not receive User A notification");

  console.log("\n2. Read-state propagation");
  const unreadUpdate = waitFor(socketA, "notifications_unread_count");
  const readResponse = await api(`/notifications/${idA}/read`, {
    method: "PUT",
    headers: { Authorization: `Bearer ${userA.token}` },
  });
  const readPayload = await unreadUpdate;
  assert(readResponse.ok, "Authenticated read endpoint succeeds");
  assert(readPayload?.unread_count === 0, "Read state broadcasts unread count");

  console.log("\n3. Missed notification remains available through REST");
  socketA.disconnect();
  const idMissed = await insertNotification(userA.userId, "missed");
  const rest = await api("/notifications", {
    headers: { Authorization: `Bearer ${userA.token}` },
  });
  const restBody = await rest.json();
  const ids = (restBody.data?.notifications ?? []).map((item) => item.id);
  assert(ids.includes(idMissed), "Disconnected notification is recoverable through REST");

  socketB.disconnect();
  console.log(`\nPassed: ${passed}  Failed: ${failed}`);
  if (failed > 0) process.exitCode = 1;
} finally {
  await database.end();
}