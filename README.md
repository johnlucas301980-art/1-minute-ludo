# 1 Minute Ludo

A production-grade multiplayer Ludo game where each match is exactly 60 seconds.

---

## Tech Stack

| Layer       | Technology               |
|-------------|--------------------------|
| Frontend    | Flutter (Android target) |
| Backend     | Node.js + Express 5      |
| Database    | PostgreSQL               |
| Realtime    | Socket.IO                |
| Language    | TypeScript (backend)     |

---

## Project Structure

```
one-minute-ludo/
├── flutter_app/                    # Flutter mobile application
│   ├── android/                    # Android build files
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/
│   │   │   │   └── app_config.dart         # API & socket URLs
│   │   │   ├── constants/
│   │   │   │   └── app_constants.dart      # App-wide constants
│   │   │   └── network/
│   │   │       ├── api_client.dart         # HTTP REST client
│   │   │       └── socket_client.dart      # Socket.IO client
│   │   └── main.dart                       # App entry point
│   ├── test/
│   ├── pubspec.yaml
│   └── analysis_options.yaml
│
├── artifacts/
│   └── api-server/                 # Node.js + Express backend
│       ├── src/
│       │   ├── config/
│       │   │   └── env.ts                  # Typed environment config
│       │   ├── db/
│       │   │   └── index.ts                # PostgreSQL pool (pg)
│       │   ├── socket/
│       │   │   └── index.ts                # Socket.IO server init
│       │   ├── routes/
│       │   │   ├── index.ts                # Route registry
│       │   │   └── health.ts               # GET /api/healthz
│       │   ├── middlewares/
│       │   ├── lib/
│       │   │   └── logger.ts               # Pino logger
│       │   ├── app.ts                      # Express app
│       │   └── index.ts                    # HTTP server + Socket.IO
│       ├── .env.example
│       └── package.json
│
├── lib/                            # Shared workspace libraries
│   ├── api-spec/                   # OpenAPI specification
│   ├── api-client-react/           # Generated React Query hooks
│   ├── api-zod/                    # Generated Zod schemas
│   └── db/                         # Drizzle ORM schema + client
│
├── .env.example                    # Root environment template
├── .gitignore
└── README.md
```

---

## Quick Start

### Backend

```bash
# 1. Install dependencies
pnpm install

# 2. Copy environment file
cp artifacts/api-server/.env.example .env
# Edit .env with your DATABASE_URL, SESSION_SECRET, etc.

# 3. Start the development server
pnpm --filter @workspace/api-server run dev
```

The API server starts on `http://localhost:5000`.
Health check: `GET /api/healthz`

### Flutter

```bash
cd flutter_app

# Install Flutter dependencies
flutter pub get

# Run on an Android emulator
flutter run

# Build a release APK
flutter build apk --release
```

---

## Environment Variables

See `.env.example` for all required variables.

| Variable        | Required | Description                                    |
|-----------------|----------|------------------------------------------------|
| `PORT`          | Yes      | Port for Express server                        |
| `DATABASE_URL`  | Yes      | PostgreSQL connection string                   |
| `SESSION_SECRET`| Yes      | Secret for signing sessions                    |
| `CORS_ORIGIN`   | No       | Allowed CORS origin (default: `*`)             |
| `LOG_LEVEL`     | No       | Pino log level (default: `info`)               |

---

## Backend API

| Method | Path           | Description         |
|--------|---------------|---------------------|
| GET    | `/api/healthz` | Health check        |

---

## Flutter Configuration

- **Android emulator** connects to backend at `10.0.2.2:5000` (host machine).
- **Physical device** — update `AppConfig.apiBaseUrl` and `AppConfig.socketUrl` to your machine's local IP.
- Target SDK: Android (primary). Flutter Web available for dev preview only.

---

## Development Notes

- All backend logs use [Pino](https://getpino.io) — do not use `console.log` in server code.
- Socket.IO and the REST API share the same HTTP server and port.
- The Flutter `SocketClient` is a singleton — call `connect()` once after auth.
- `AppConfig.isDevelopment` must be set to `false` before a production build.
