# 1 Minute Ludo

A production-grade multiplayer Ludo game where each match is exactly 60 seconds.

---

## Tech Stack

| Layer    | Technology               |
|----------|--------------------------|
| Mobile   | Flutter (Android target) |
| Backend  | Node.js + Express 5      |
| Database | PostgreSQL               |
| Realtime | Socket.IO 4              |
| Language | TypeScript (backend)     |

---

## Project Structure

```
1-minute-ludo/
├── mobile/                             # Flutter Android application
│   ├── android/                        # Android build files
│   ├── lib/
│   │   ├── core/
│   │   │   └── config/
│   │   │       └── app_config.dart     # API & Socket.IO URLs
│   │   └── main.dart                   # App entry point
│   ├── test/
│   ├── pubspec.yaml
│   └── analysis_options.yaml
│
├── backend/                            # Node.js + Express backend
│   ├── src/
│   │   ├── config/
│   │   │   └── env.ts                  # Typed env validation
│   │   ├── db/
│   │   │   └── index.ts                # PostgreSQL pool
│   │   ├── socket/
│   │   │   └── index.ts                # Socket.IO server init
│   │   ├── routes/
│   │   │   ├── index.ts
│   │   │   └── health.ts               # GET /api/healthz
│   │   ├── middlewares/
│   │   ├── lib/
│   │   │   └── logger.ts               # Pino logger
│   │   ├── app.ts                      # Express app
│   │   └── index.ts                    # HTTP server entry point
│   └── .env.example
│
├── docs/                               # Technical documentation
│
├── .env.example
├── .gitignore
└── README.md
```

---

## Quick Start

### Backend

```bash
# 1. Install dependencies
pnpm install

# 2. Copy and configure environment
cp backend/.env.example .env
# Set DATABASE_URL, SESSION_SECRET, etc.

# 3. Start the development server
pnpm --filter @workspace/backend run dev
```

Server starts on `http://localhost:5000`.
Health check: `GET /api/healthz`

### Flutter (Mobile)

```bash
cd mobile

# Install Flutter dependencies
flutter pub get

# Run on Android emulator
flutter run

# Build release APK
flutter build apk --release
```

---

## Environment Variables

See `.env.example` for all variables.

| Variable         | Required | Description                         |
|------------------|----------|-------------------------------------|
| `PORT`           | Yes      | Express server port                 |
| `DATABASE_URL`   | Yes      | PostgreSQL connection string        |
| `SESSION_SECRET` | Yes      | Secret for signing sessions         |
| `CORS_ORIGIN`    | No       | Allowed CORS origin (default: `*`)  |
| `LOG_LEVEL`      | No       | Pino log level (default: `info`)    |

---

## Backend API

| Method | Path           | Description  |
|--------|----------------|--------------|
| GET    | `/api/healthz` | Health check |

---

## Flutter Configuration

Edit `mobile/lib/core/config/app_config.dart`:

- **Android emulator** — `10.0.2.2:5000` routes to the host machine. No change needed.
- **Physical device** — update `apiBaseUrl` and `socketUrl` to your machine's local IP.
- **Production** — set `isDevelopment = false` and point URLs to your production domain.

---

## Development Notes

- All backend logs use [Pino](https://getpino.io) — never use `console.log` in server code.
- Socket.IO and REST share one HTTP server on the same port.
- The PostgreSQL pool is lazy — the server starts and warns if `DATABASE_URL` is missing.
- See `docs/` for architecture, API reference, and deployment guides.
