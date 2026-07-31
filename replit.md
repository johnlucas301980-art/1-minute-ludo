# 1 Minute Ludo

## User preferences

- Wait for explicit coding tasks before doing any work.
- Modify only the files explicitly mentioned in each task.
- Do not install dependencies, run pnpm install, start the backend, build Flutter, connect a database, or explore the repository unless specifically asked.
- Commit and push after each completed task.


A production-grade multiplayer Ludo game where each match is exactly 60 seconds.

## Stack

| Layer    | Technology               |
|----------|--------------------------|
| Mobile   | Flutter (Android)        |
| Backend  | Node.js + Express 5      |
| Database | PostgreSQL (Replit)      |
| Realtime | Socket.IO 4              |
| Language | TypeScript (backend)     |

## How to run

The **Backend** workflow starts automatically. It builds (esbuild) then starts the server on `$PORT`.

```
pnpm --filter @workspace/backend run dev
```

To run database migrations manually:

```
pnpm --filter @workspace/backend run migrate
```

## Environment variables

All required variables are already configured:

| Variable                  | Source          | Notes                              |
|---------------------------|-----------------|------------------------------------|
| `DATABASE_URL`            | Replit managed  | Points to Replit's PostgreSQL      |
| `PORT`                    | Replit managed  | Assigned by the workflow           |
| `SESSION_SECRET`          | Replit Secret   | Already set                        |
| `JWT_ACCESS_SECRET`       | Shared env var  | Already set                        |
| `JWT_REFRESH_SECRET`      | Shared env var  | Already set                        |
| `JWT_PASSWORD_RESET_SECRET` | Shared env var | Already set                        |
| `SMTP_*`                  | Optional        | Password reset emails skipped if unset |

## Project structure

```
backend/     Node.js + Express + Socket.IO + TypeScript
mobile/      Flutter Android application
docs/        Architecture, API, Socket events, roadmap, changelog
```

## Current status

**v0.46.0 — Auth & Country system redesign applied.**

- 599 backend unit tests passing
- 434 Flutter tests (last verified 2026-07-20; require Flutter SDK locally)
- All 17 database migrations defined (run `pnpm --filter @workspace/backend run migrate` to apply migration 0017)
- Migration 0017 adds the `country_access` table with 80 seeded countries

### Auth & Country system (Phase 1–5)
- **Phase 1 — Country Detection:** `GET /api/geo/detect` auto-detects country from IP; returns full country list.
- **Phase 2 — Phone Validation:** Mobile number must start with the selected country's dial code (E.164).
- **Phase 3 & 4 — Auth UX & Messages:** Field-level errors shown inline with red border; Snackbar only for network/server errors; password now requires uppercase + lowercase + number.
- **Phase 5 — Admin Country Control:** `GET /api/admin/countries` + `PUT /api/admin/countries/:iso2` — enable/disable countries and per-feature flags (registration, login, gameplay, recharge, withdraw, tournament) without rebuilding the app.

See `docs/02_PROJECT_STATUS.md` for full phase history and `docs/12_ROADMAP.md` for the roadmap.

## User preferences

- Do NOT redesign or refactor the existing architecture.
- Do NOT introduce new features outside the current roadmap phase.
- Keep the existing project structure exactly as-is.
- Always read `docs/02_PROJECT_STATUS.md` and `docs/09_CHANGELOG.md` before starting any phase.
- Complete one phase before starting the next.
- Update `docs/02_PROJECT_STATUS.md` and `docs/09_CHANGELOG.md` after every phase.
- Push every completed phase to GitHub.
