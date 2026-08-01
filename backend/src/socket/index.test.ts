import { beforeEach, describe, expect, it, vi } from "vitest";

// ---------------------------------------------------------------------------
// Hoisted mocks — stable references shared across all dynamic module loads
// ---------------------------------------------------------------------------

const {
  MockSocketIOServer,
  mockIo,
  setupMatchmakingHandlers,
  setupGameLobbyHandlers,
  setupResumeGameHandlers,
  setupNotificationRooms,
  startNotificationDelivery,
} = vi.hoisted(() => {
  const mockIo = { on: vi.fn() };
  return {
    MockSocketIOServer: vi.fn(() => mockIo),
    mockIo,
    setupMatchmakingHandlers: vi.fn(),
    setupGameLobbyHandlers: vi.fn(),
    setupResumeGameHandlers: vi.fn(),
    setupNotificationRooms: vi.fn(),
    startNotificationDelivery: vi.fn().mockResolvedValue(undefined),
  };
});

vi.mock("socket.io", () => ({ Server: MockSocketIOServer }));
vi.mock("../lib/logger.js", () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}));
vi.mock("./matchmaking.js", () => ({ setupMatchmakingHandlers }));
vi.mock("./game_lobby.js", () => ({ setupGameLobbyHandlers }));
vi.mock("./resume_game.js", () => ({ setupResumeGameHandlers }));
vi.mock("./notification_delivery.js", () => ({
  setupNotificationRooms,
  startNotificationDelivery,
}));

// ---------------------------------------------------------------------------
// Reset module registry before each test so the `io` singleton starts as null
// ---------------------------------------------------------------------------

beforeEach(() => {
  vi.resetModules();
  vi.clearAllMocks();
  startNotificationDelivery.mockResolvedValue(undefined);
  delete process.env["CORS_ORIGIN"];
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Import a fresh copy of the module under test (io singleton starts null). */
async function freshModule() {
  return import("./index.js") as Promise<typeof import("./index.js")>;
}

const fakeHttpServer = {} as import("node:http").Server;

// ---------------------------------------------------------------------------
// getIO()
// ---------------------------------------------------------------------------

describe("getIO", () => {
  it("throws when called before initSocket", async () => {
    const { getIO } = await freshModule();

    expect(() => getIO()).toThrow(
      "Socket.IO has not been initialized. Call initSocket() first.",
    );
  });

  it("returns the io instance after initSocket has been called", async () => {
    const { initSocket, getIO } = await freshModule();

    initSocket(fakeHttpServer);

    expect(getIO()).toBe(mockIo);
  });
});

// ---------------------------------------------------------------------------
// initSocket()
// ---------------------------------------------------------------------------

describe("initSocket", () => {
  it("constructs SocketIOServer with the provided HTTP server", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(MockSocketIOServer).toHaveBeenCalledWith(
      fakeHttpServer,
      expect.objectContaining({ transports: ["websocket", "polling"] }),
    );
  });

  it("uses CORS_ORIGIN env var when set", async () => {
    process.env["CORS_ORIGIN"] = "https://example.com";
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(MockSocketIOServer).toHaveBeenCalledWith(
      fakeHttpServer,
      expect.objectContaining({
        cors: expect.objectContaining({ origin: "https://example.com" }),
      }),
    );
  });

  it("defaults CORS origin to '*' when CORS_ORIGIN is not set", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(MockSocketIOServer).toHaveBeenCalledWith(
      fakeHttpServer,
      expect.objectContaining({
        cors: expect.objectContaining({ origin: "*" }),
      }),
    );
  });

  it("includes GET and POST methods and credentials in CORS config", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(MockSocketIOServer).toHaveBeenCalledWith(
      fakeHttpServer,
      expect.objectContaining({
        cors: {
          origin: "*",
          methods: ["GET", "POST"],
          credentials: true,
        },
      }),
    );
  });

  it("calls setupMatchmakingHandlers with the io instance", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(setupMatchmakingHandlers).toHaveBeenCalledOnce();
    expect(setupMatchmakingHandlers).toHaveBeenCalledWith(mockIo);
  });

  it("calls setupGameLobbyHandlers with the io instance", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(setupGameLobbyHandlers).toHaveBeenCalledOnce();
    expect(setupGameLobbyHandlers).toHaveBeenCalledWith(mockIo);
  });

  it("calls setupNotificationRooms with the io instance", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(setupNotificationRooms).toHaveBeenCalledOnce();
    expect(setupNotificationRooms).toHaveBeenCalledWith(mockIo);
  });

  it("calls startNotificationDelivery with the io instance", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);
    await vi.waitFor(() => expect(startNotificationDelivery).toHaveBeenCalled());

    expect(startNotificationDelivery).toHaveBeenCalledWith(mockIo);
  });

  it("returns the created io instance", async () => {
    const { initSocket } = await freshModule();

    const result = initSocket(fakeHttpServer);

    expect(result).toBe(mockIo);
  });

  it("registers a global connection handler for per-socket error logging", async () => {
    const { initSocket } = await freshModule();

    initSocket(fakeHttpServer);

    expect(mockIo.on).toHaveBeenCalledWith("connection", expect.any(Function));
  });

  it("registers a socket-level error handler inside the connection callback", async () => {
    const { initSocket } = await freshModule();
    initSocket(fakeHttpServer);

    const connectionCall = mockIo.on.mock.calls.find(([ev]) => ev === "connection");
    const connectionHandler = connectionCall![1] as (socket: unknown) => void;

    const mockSocket = { id: "sock-1", on: vi.fn() };
    connectionHandler(mockSocket);

    expect(mockSocket.on).toHaveBeenCalledWith("error", expect.any(Function));
  });

  it("does not throw when startNotificationDelivery rejects", async () => {
    startNotificationDelivery.mockRejectedValue(new Error("db unavailable"));
    const { initSocket } = await freshModule();

    await expect(
      Promise.resolve(initSocket(fakeHttpServer)),
    ).resolves.not.toThrow();

    // Allow the rejection to be handled internally
    await vi.waitFor(() =>
      expect(startNotificationDelivery).toHaveBeenCalled(),
    );
  });
});
