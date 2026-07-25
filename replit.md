# 1 Minute Ludo

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

**v0.46.0 — Phase 12.1 Final QA complete.**

- 599 backend unit tests passing
- 434 Flutter tests (last verified 2026-07-20; require Flutter SDK locally)
- All 16 database migrations applied
- Next: Phase 12.2 — Production deployment

See `docs/02_PROJECT_STATUS.md` for full phase history and `docs/12_ROADMAP.md` for the roadmap.

## User preferences

- Do NOT redesign or refactor the existing architecture.
- Do NOT introduce new features outside the current roadmap phase.
- Keep the existing project structure exactly as-is.
- Always read `docs/02_PROJECT_STATUS.md` and `docs/09_CHANGELOG.md` before starting any phase.
- Complete one phase before starting the next.
- Update `docs/02_PROJECT_STATUS.md` and `docs/09_CHANGELOG.md` after every phase.
- Push every completed phase to GitHub.
