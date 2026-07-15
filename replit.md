# 1 Minute Ludo

A production-grade multiplayer Ludo game where each match is exactly 60 seconds.

## Run & Operate

- Workflow `Backend` runs the API server: `PORT=5000 CORS_ORIGIN=* LOG_LEVEL=info pnpm --filter @workspace/backend run dev`
- `pnpm run typecheck` — typecheck the backend
- Required env: `DATABASE_URL` — Postgres connection string (Replit's built-in Postgres is already provisioned and connected)
- `SESSION_SECRET` is set as a Replit secret
- Verified: `GET /api/healthz` → `{"status":"ok"}`, backend builds and typechecks cleanly
- The Flutter mobile app in `mobile/` does not run in Replit's preview (Android-only); it must be run in an emulator or on a device outside Replit

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5 + Socket.IO 4
- DB: PostgreSQL + pg
- Mobile: Flutter (Android target)

## Where things live

- `mobile/` — Flutter Android application
- `backend/` — Node.js + Express + Socket.IO backend
- `docs/` — Technical documentation

## Architecture decisions

- Socket.IO and REST API share one HTTP server and port.
- PostgreSQL pool is lazy — server starts cleanly without DATABASE_URL (warns instead of crashing).
- Flutter connects to `10.0.2.2:5000` from Android emulator; update `AppConfig` for physical devices.

## User preferences

- Backend lives at `backend/`, Flutter app at `mobile/` — do not move these or place them under `artifacts/`.
- Keep `lib/` removed — no shared workspace libraries in this project.
- Do not add game logic, constants, or feature code until explicitly requested (Phase 2+).

## Gotchas

- Never use `console.log` in backend code — use `req.log` in routes and the `logger` singleton elsewhere.
- Run `pnpm install` after any package.json change.
