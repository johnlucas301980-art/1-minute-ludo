# 1 Minute Ludo

A production-grade multiplayer Ludo game where each match is exactly 60 seconds.

## Stack

| Layer    | Technology               |
|----------|--------------------------|
| Mobile   | Flutter (Android target) |
| Backend  | Node.js + Express 5      |
| Database | PostgreSQL (Replit built-in) |
| Realtime | Socket.IO 4              |
| Language | TypeScript (backend)     |

## Running the backend

The **Backend** workflow runs the Express + Socket.IO server on port 5000:

```
pnpm --filter @workspace/backend run dev
```

This builds TypeScript via `build.mjs` (esbuild) and starts `dist/index.mjs`.

Health check: `GET /api/healthz` → `{"status":"ok"}`

## Environment variables / secrets

| Key                | Where set      | Notes                                  |
|--------------------|----------------|----------------------------------------|
| `PORT`             | Shared env var | Set to `5000`                          |
| `DATABASE_URL`     | Runtime-managed | Injected by Replit (built-in Postgres) |
| `SESSION_SECRET`   | Replit Secret  | Signs sessions                         |
| `JWT_ACCESS_SECRET`  | Replit Secret | Signs access tokens                    |
| `JWT_REFRESH_SECRET` | Replit Secret | Signs refresh tokens                   |

## Project structure

```
backend/     Node.js + Express backend (TypeScript)
mobile/      Flutter Android application
docs/        Architecture and API reference
```

## User preferences

- Do not modify application code unless explicitly asked.
- Do not create new features without instruction.
- Do not change documentation.
- Do not commit or push anything.
