import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Mock firebase-admin/database before any imports
// ---------------------------------------------------------------------------

const { mockSnapshot, mockRef } = vi.hoisted(() => {
  const mockSnapshot = {
    exists: vi.fn<() => boolean>(),
    val: vi.fn<() => unknown>(),
  };
  const mockRef = {
    once: vi.fn().mockResolvedValue(mockSnapshot),
    set: vi.fn().mockResolvedValue(undefined),
  };
  return { mockSnapshot, mockRef };
});

vi.mock("firebase-admin/database", () => ({
  getDatabase: vi.fn(() => ({
    ref: vi.fn(() => mockRef),
  })),
}));

// ---------------------------------------------------------------------------
// Imports (after mock registration)
// ---------------------------------------------------------------------------

import {
  _resetForTesting,
  createWalletIfMissing,
  loadWallet,
  saveWallet,
  syncWallet,
} from "./firebase_wallet_service.js";

import {
  _resetForTesting as resetWallet,
  creditPlayer,
  getBalance,
} from "./wallet.service.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeDoc(balance: number, updatedAt: number) {
  return { balance, updatedAt };
}

/** Simulate Firebase having a record with the given balance and timestamp. */
function setFirebase(balance: number, updatedAt: number) {
  mockSnapshot.exists.mockReturnValue(true);
  mockSnapshot.val.mockReturnValue(makeDoc(balance, updatedAt));
}

/** Simulate Firebase having no record for this player. */
function setFirebaseMissing() {
  mockSnapshot.exists.mockReturnValue(false);
  mockSnapshot.val.mockReturnValue(null);
}

beforeEach(() => {
  vi.clearAllMocks();
  mockRef.once.mockResolvedValue(mockSnapshot);
  mockRef.set.mockResolvedValue(undefined);
  _resetForTesting();
  resetWallet();
});

// ---------------------------------------------------------------------------
// loadWallet
// ---------------------------------------------------------------------------

describe("loadWallet", () => {
  it("does nothing when Firebase has no record", async () => {
    setFirebaseMissing();
    await loadWallet("p1");
    expect(getBalance("p1")).toBe(0);
  });

  it("credits local balance to match Firebase when Firebase is higher", async () => {
    setFirebase(200, 1000);
    await loadWallet("p1");
    expect(getBalance("p1")).toBe(200);
  });

  it("debits local balance to match Firebase when Firebase is lower", async () => {
    creditPlayer("p1", 300);
    setFirebase(100, 1000);
    await loadWallet("p1");
    expect(getBalance("p1")).toBe(100);
  });

  it("leaves balance unchanged when Firebase matches local", async () => {
    creditPlayer("p1", 150);
    setFirebase(150, 1000);
    await loadWallet("p1");
    expect(getBalance("p1")).toBe(150);
  });

  it("reads from the correct Firebase path for the given playerId", async () => {
    const { getDatabase } = await import("firebase-admin/database");
    setFirebaseMissing();
    await loadWallet("player-42");
    const dbInstance = (getDatabase as ReturnType<typeof vi.fn>).mock.results[0]?.value;
    expect(dbInstance.ref).toHaveBeenCalledWith("wallets/player-42");
  });

  it("updates local sync timestamp after loading", async () => {
    setFirebase(100, 9999);
    // After load, a subsequent sync should prefer local (timestamps equal)
    // — verified indirectly via syncWallet behavior in the sync suite
    await loadWallet("p1");
    // If timestamp was stored, syncWallet will NOT reload (Firebase not newer)
    setFirebase(50, 9999); // same timestamp, lower balance
    await syncWallet("p1");
    // Local should have been saved to Firebase (local wins), balance stays 100
    expect(getBalance("p1")).toBe(100);
  });
});

// ---------------------------------------------------------------------------
// saveWallet
// ---------------------------------------------------------------------------

describe("saveWallet", () => {
  it("writes local balance to Firebase", async () => {
    creditPlayer("p1", 250);
    setFirebaseMissing();
    await saveWallet("p1");
    const [doc] = mockRef.set.mock.calls[0] as [{ balance: number; updatedAt: number }];
    expect(doc.balance).toBe(250);
  });

  it("includes a positive updatedAt timestamp in the written document", async () => {
    setFirebaseMissing();
    await saveWallet("p1");
    const [doc] = mockRef.set.mock.calls[0] as [{ balance: number; updatedAt: number }];
    expect(doc.updatedAt).toBeGreaterThan(0);
  });

  it("writes zero balance for a player who has never been credited", async () => {
    setFirebaseMissing();
    await saveWallet("p1");
    const [doc] = mockRef.set.mock.calls[0] as [{ balance: number; updatedAt: number }];
    expect(doc.balance).toBe(0);
  });

  it("calls Firebase set exactly once per saveWallet call", async () => {
    setFirebaseMissing();
    await saveWallet("p1");
    expect(mockRef.set).toHaveBeenCalledTimes(1);
  });

  it("writes to the correct Firebase path", async () => {
    const { getDatabase } = await import("firebase-admin/database");
    setFirebaseMissing();
    await saveWallet("player-99");
    const dbInstance = (getDatabase as ReturnType<typeof vi.fn>).mock.results[0]?.value;
    expect(dbInstance.ref).toHaveBeenCalledWith("wallets/player-99");
  });
});

// ---------------------------------------------------------------------------
// createWalletIfMissing
// ---------------------------------------------------------------------------

describe("createWalletIfMissing", () => {
  it("saves to Firebase when no record exists", async () => {
    setFirebaseMissing();
    await createWalletIfMissing("p1");
    expect(mockRef.set).toHaveBeenCalledTimes(1);
  });

  it("creates the wallet with the current local balance", async () => {
    creditPlayer("p1", 75);
    setFirebaseMissing();
    await createWalletIfMissing("p1");
    const [doc] = mockRef.set.mock.calls[0] as [{ balance: number }];
    expect(doc.balance).toBe(75);
  });

  it("creates with zero balance for a brand-new player", async () => {
    setFirebaseMissing();
    await createWalletIfMissing("p1");
    const [doc] = mockRef.set.mock.calls[0] as [{ balance: number }];
    expect(doc.balance).toBe(0);
  });

  it("does NOT write to Firebase when the record already exists", async () => {
    setFirebase(100, 1000);
    await createWalletIfMissing("p1");
    expect(mockRef.set).not.toHaveBeenCalled();
  });

  it("does not modify local balance when the record already exists", async () => {
    creditPlayer("p1", 50);
    setFirebase(999, 1000);
    await createWalletIfMissing("p1");
    // Local balance must remain untouched — createWalletIfMissing is write-only
    expect(getBalance("p1")).toBe(50);
  });
});

// ---------------------------------------------------------------------------
// syncWallet — no Firebase record
// ---------------------------------------------------------------------------

describe("syncWallet — no Firebase record", () => {
  it("saves local balance to Firebase when no record exists", async () => {
    creditPlayer("p1", 100);
    setFirebaseMissing();
    await syncWallet("p1");
    expect(mockRef.set).toHaveBeenCalledTimes(1);
    const [doc] = mockRef.set.mock.calls[0] as [{ balance: number }];
    expect(doc.balance).toBe(100);
  });

  it("does not alter local balance when saving to Firebase", async () => {
    creditPlayer("p1", 100);
    setFirebaseMissing();
    await syncWallet("p1");
    expect(getBalance("p1")).toBe(100);
  });
});

// ---------------------------------------------------------------------------
// syncWallet — Firebase is newer
// ---------------------------------------------------------------------------

describe("syncWallet — Firebase is newer", () => {
  it("loads Firebase balance into local when Firebase updatedAt is higher", async () => {
    creditPlayer("p1", 50);
    // localTs = 0 (never synced), Firebase updatedAt = 5000 → Firebase wins
    setFirebase(300, 5000);
    await syncWallet("p1");
    expect(getBalance("p1")).toBe(300);
  });

  it("does NOT write to Firebase when Firebase is newer", async () => {
    setFirebase(300, 5000);
    await syncWallet("p1");
    expect(mockRef.set).not.toHaveBeenCalled();
  });

  it("never overwrites a newer Firebase balance with an older local balance", async () => {
    creditPlayer("p1", 10);
    setFirebase(500, 99999);
    await syncWallet("p1");
    // Local should now reflect Firebase value
    expect(getBalance("p1")).toBe(500);
  });
});

// ---------------------------------------------------------------------------
// syncWallet — local is newer
// ---------------------------------------------------------------------------

describe("syncWallet — local is newer", () => {
  it("saves local balance to Firebase when local sync timestamp is equal to Firebase", async () => {
    // Load first to record timestamp = 1000
    setFirebase(100, 1000);
    await loadWallet("p1");
    // Now Firebase still has updatedAt=1000, localTs=1000 → local wins (equal)
    creditPlayer("p1", 50); // local is now 150
    setFirebase(100, 1000);
    await syncWallet("p1");
    const [doc] = mockRef.set.mock.calls[0] as [{ balance: number }];
    expect(doc.balance).toBe(150);
  });

  it("saves local balance to Firebase when local was synced more recently", async () => {
    // Simulate a prior save that set localTs to a large value
    setFirebaseMissing();
    await saveWallet("p1"); // records localTs = now (large)

    creditPlayer("p1", 200);
    // Firebase has an older timestamp
    setFirebase(50, 1);
    await syncWallet("p1");

    // set should be called (once for saveWallet above + once for syncWallet)
    const lastDoc = mockRef.set.mock.calls.at(-1)?.[0] as { balance: number };
    expect(lastDoc.balance).toBe(200);
  });
});

// ---------------------------------------------------------------------------
// syncWallet — timestamp tie-breaking
// ---------------------------------------------------------------------------

describe("syncWallet — tie-breaking (equal timestamps)", () => {
  it("treats local as authoritative when timestamps are equal", async () => {
    setFirebase(100, 5000);
    await loadWallet("p1"); // localTs = 5000
    creditPlayer("p1", 25); // local = 125

    setFirebase(100, 5000); // Firebase unchanged
    await syncWallet("p1");

    // Local wins: set should have been called with 125
    const lastDoc = mockRef.set.mock.calls.at(-1)?.[0] as { balance: number };
    expect(lastDoc.balance).toBe(125);
  });
});
