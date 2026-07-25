import { beforeEach, describe, expect, it, vi } from "vitest";

const { pool } = vi.hoisted(() => {
  const client = {
    query: vi.fn(),
    release: vi.fn(),
  };
  const pool = {
    query: vi.fn(),
    connect: vi.fn().mockResolvedValue(client),
    _client: client,
  };
  return { pool };
});

vi.mock("../db/index", () => ({ pool }));

import {
  InsufficientBalanceError,
  depositPoints,
  findOrCreateWallet,
  findWalletByUserId,
  getTransactions,
  withdrawPoints,
  type TransactionRow,
  type WalletRow,
} from "./wallet.service";

function makeWallet(overrides: Partial<WalletRow> = {}): WalletRow {
  return {
    id: "wallet-1",
    user_id: "user-1",
    points: "100.00",
    total_deposit: "150.00",
    total_withdraw: "50.00",
    updated_at: new Date("2026-01-02T00:00:00Z"),
    ...overrides,
  };
}

function makeTransaction(overrides: Partial<TransactionRow> = {}): TransactionRow {
  return {
    id: "transaction-1",
    user_id: "user-1",
    type: "deposit",
    amount: "25.00",
    status: "completed",
    reference: "payment-1",
    created_at: new Date("2026-01-02T00:00:00Z"),
    ...overrides,
  };
}

function getClient() {
  return pool._client as {
    query: ReturnType<typeof vi.fn>;
    release: ReturnType<typeof vi.fn>;
  };
}

beforeEach(() => {
  vi.resetAllMocks();
  pool.connect.mockResolvedValue(pool._client);
});

describe("InsufficientBalanceError", () => {
  it("contains the available and requested balances", () => {
    const error = new InsufficientBalanceError(12.5, 20);

    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe("InsufficientBalanceError");
    expect(error.message).toBe("Insufficient balance: available 12.5, requested 20.");
  });
});

describe("findWalletByUserId", () => {
  it("returns the matching wallet and scopes the query to the user", async () => {
    const wallet = makeWallet();
    pool.query.mockResolvedValue({ rows: [wallet] });

    await expect(findWalletByUserId("user-1")).resolves.toEqual(wallet);

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/FROM wallets/i);
    expect(sql).toMatch(/WHERE user_id = \$1/i);
    expect(params).toEqual(["user-1"]);
  });

  it("returns null when no wallet exists", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(findWalletByUserId("missing-user")).resolves.toBeNull();
  });
});

describe("findOrCreateWallet", () => {
  it("uses an upsert and returns the database wallet row", async () => {
    const wallet = makeWallet();
    pool.query.mockResolvedValue({ rows: [wallet] });

    await expect(findOrCreateWallet("user-1")).resolves.toEqual(wallet);

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO wallets/i);
    expect(sql).toMatch(/ON CONFLICT \(user_id\) DO UPDATE/i);
    expect(sql).toMatch(/RETURNING/i);
    expect(params).toEqual(["user-1"]);
  });
});

describe("getTransactions", () => {
  it("returns newest-first transaction rows with pagination parameters", async () => {
    const transactions = [makeTransaction()];
    pool.query.mockResolvedValue({ rows: transactions });

    await expect(getTransactions("user-1", 10, 20)).resolves.toEqual(transactions);

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toMatch(/FROM transactions/i);
    expect(sql).toMatch(/WHERE user_id = \$1/i);
    expect(sql).toMatch(/ORDER BY created_at DESC/i);
    expect(params).toEqual(["user-1", 10, 20]);
  });

  it("uses the documented default pagination values", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await expect(getTransactions("user-1")).resolves.toEqual([]);

    expect(pool.query.mock.calls[0][1]).toEqual(["user-1", 20, 0]);
  });
});

describe("depositPoints", () => {
  it("runs the wallet and ledger updates in one transaction", async () => {
    const client = getClient();
    const wallet = makeWallet({ points: "125.00", total_deposit: "175.00" });
    const pending = makeTransaction({ status: "pending" });
    const completed = makeTransaction();
    client.query
      .mockResolvedValueOnce({}) // BEGIN
      .mockResolvedValueOnce({ rows: [makeWallet()] }) // wallet upsert
      .mockResolvedValueOnce({ rows: [pending] }) // pending transaction
      .mockResolvedValueOnce({ rows: [wallet] }) // wallet credit
      .mockResolvedValueOnce({ rows: [completed] }) // completed transaction
      .mockResolvedValueOnce({}); // COMMIT

    await expect(depositPoints("user-1", 25, "payment-1")).resolves.toEqual({
      wallet,
      transaction: completed,
    });

    expect(client.query).toHaveBeenCalledTimes(6);
    expect(client.query.mock.calls[0][0]).toBe("BEGIN");
    expect(client.query.mock.calls[2][1]).toEqual(["user-1", 25, "payment-1"]);
    expect(client.query.mock.calls[5][0]).toBe("COMMIT");
    expect(client.release).toHaveBeenCalledOnce();
  });

  it("stores a missing reference as null", async () => {
    const client = getClient();
    client.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({ rows: [makeWallet()] })
      .mockResolvedValueOnce({ rows: [makeTransaction({ status: "pending", reference: null })] })
      .mockResolvedValueOnce({ rows: [makeWallet({ points: "110.00" })] })
      .mockResolvedValueOnce({ rows: [makeTransaction({ reference: null })] })
      .mockResolvedValueOnce({});

    await depositPoints("user-1", 10);

    expect(client.query.mock.calls[2][1]).toEqual(["user-1", 10, null]);
  });

  it("rolls back, releases the client, and propagates transaction errors", async () => {
    const client = getClient();
    const failure = new Error("deposit failed");
    client.query
      .mockResolvedValueOnce({})
      .mockRejectedValueOnce(failure)
      .mockResolvedValueOnce({});

    await expect(depositPoints("user-1", 25)).rejects.toThrow("deposit failed");

    expect(client.query.mock.calls.at(-1)?.[0]).toBe("ROLLBACK");
    expect(client.release).toHaveBeenCalledOnce();
  });
});

describe("withdrawPoints", () => {
  it("locks the wallet and completes the debit transaction", async () => {
    const client = getClient();
    const wallet = makeWallet({ points: "75.00", total_withdraw: "75.00" });
    const pending = makeTransaction({ type: "withdraw", status: "pending" });
    const completed = makeTransaction({ type: "withdraw" });
    client.query
      .mockResolvedValueOnce({}) // BEGIN
      .mockResolvedValueOnce({ rows: [makeWallet()] }) // wallet upsert
      .mockResolvedValueOnce({}) // FOR UPDATE
      .mockResolvedValueOnce({ rows: [pending] }) // pending transaction
      .mockResolvedValueOnce({ rows: [wallet] }) // wallet debit
      .mockResolvedValueOnce({ rows: [completed] }) // completed transaction
      .mockResolvedValueOnce({}); // COMMIT

    await expect(withdrawPoints("user-1", 25, "withdrawal-1")).resolves.toEqual({
      wallet,
      transaction: completed,
    });

    expect(client.query.mock.calls[2][0]).toMatch(/FOR UPDATE/i);
    expect(client.query.mock.calls[3][1]).toEqual(["user-1", 25, "withdrawal-1"]);
    expect(client.query.mock.calls[6][0]).toBe("COMMIT");
    expect(client.release).toHaveBeenCalledOnce();
  });

  it("rolls back once and throws InsufficientBalanceError when funds are low", async () => {
    const client = getClient();
    client.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({ rows: [makeWallet({ points: "10.00" })] })
      .mockResolvedValueOnce({});

    await expect(withdrawPoints("user-1", 25)).rejects.toBeInstanceOf(
      InsufficientBalanceError,
    );

    expect(client.query.mock.calls.map(([sql]) => sql)).toEqual([
      "BEGIN",
      expect.stringMatching(/INSERT INTO wallets/i),
      expect.stringMatching(/FOR UPDATE/i),
      "ROLLBACK",
    ]);
    expect(client.release).toHaveBeenCalledOnce();
  });

  it("rolls back and releases the client when a debit query fails", async () => {
    const client = getClient();
    const failure = new Error("withdraw failed");
    client.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({ rows: [makeWallet()] })
      .mockResolvedValueOnce({})
      .mockRejectedValueOnce(failure)
      .mockResolvedValueOnce({});

    await expect(withdrawPoints("user-1", 25)).rejects.toThrow("withdraw failed");

    expect(client.query.mock.calls.at(-1)?.[0]).toBe("ROLLBACK");
    expect(client.release).toHaveBeenCalledOnce();
  });
});