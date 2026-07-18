# 06_API.md

# REST API SPECIFICATION

Base URL

/api

------------------------------------------------------------------------

## Authentication

### POST /auth/register

Create a new user.

Request: - full_name - email - mobile - password

Response: - success - player_id - access_token

------------------------------------------------------------------------

### POST /auth/login

Request: - email/mobile - password

Response: - access_token - refresh_token - profile

------------------------------------------------------------------------

### POST /auth/google

Google Sign In.

------------------------------------------------------------------------

### POST /auth/logout

Logout current user.

------------------------------------------------------------------------

## Profile

### GET /profile

Return current profile.

### PUT /profile

Update profile information.

### PUT /profile/avatar

Upload an avatar image for the authenticated player.

Request:
-   Content-Type: `multipart/form-data`
-   Field: `avatar` (file — required)
-   Accepted types: `image/jpeg`, `image/png`, `image/webp`
-   Maximum size: 2 MB

Response (200):
-   success: true
-   data.avatar: public URL of the uploaded file

Notes:
-   File is stored as `uploads/avatars/<user-id>.<ext>` on the server; uploading again replaces the previous file.
-   The generated URL is persisted to the `avatar` column of the users table.
-   Files are served via Express static at `/uploads/avatars/<filename>`.
-   Implemented in Phase 3.6.

### PUT /profile/password

Change password (requires authentication).

Request:
-   current_password (required, string)
-   new_password (required, string — ≥8 chars, ≥1 letter, ≥1 digit, must differ from current)

Response (200):
-   success: true
-   message: "Password changed successfully."

Notes:
-   Verifies current_password against the stored bcrypt hash before accepting any change.
-   New password is hashed with bcrypt cost factor 12.
-   All refresh tokens for the account are revoked on success (all active sessions invalidated).
-   Implemented in Phase 3.3.

------------------------------------------------------------------------

## Wallet

### GET /wallet

Return the authenticated player's wallet balance. A wallet is created
automatically on first access — no explicit creation step required.

Response (200):
-   success: true
-   data.wallet.id
-   data.wallet.points         — current balance (number)
-   data.wallet.total_deposit  — lifetime deposits (number)
-   data.wallet.total_withdraw — lifetime withdrawals (number)
-   data.wallet.updated_at

Notes:
-   Implemented in Phase 4.1.

### GET /wallet/history

Return a paginated list of the player's transactions, newest first.

Query parameters:
-   limit  — records to return (1–100, default 20; values outside range are clamped)
-   offset — records to skip  (≥ 0,   default 0;  negative values reset to 0)

Response (200):
-   success: true
-   data.transactions — array of { id, type, amount, status, reference, created_at }
-   data.pagination   — { limit, offset, count }

Notes:
-   Implemented in Phase 4.1.

### POST /wallet/deposit

Credit points to the authenticated player's wallet.

Request body:
-   amount    — positive number of points to credit (required; ≤ 1 000 000; rounded to 2 d.p.)
-   reference — optional external reference string (≤ 255 chars; e.g. gateway transaction ID)

Response (200):
-   success: true
-   data.wallet       — updated wallet snapshot (id, points, total_deposit, total_withdraw, updated_at)
-   data.transaction  — completed deposit record (id, type, amount, status, reference, created_at)

Error responses:
-   400 — amount missing, non-positive, non-finite, or exceeds maximum; reference too long
-   401 — missing or invalid Bearer token
-   500 — unexpected server error

Notes:
-   Provider-agnostic: records the internal ledger movement only. The caller must verify the real-world payment succeeded before calling this endpoint.
-   Implemented in Phase 4.4.

### POST /wallet/withdraw

Debit points from the authenticated player's wallet.

Request body:
-   amount    — positive number of points to debit (required; must not exceed current balance; ≤ 1 000 000)
-   reference — optional external reference string (≤ 255 chars)

Response (200):
-   success: true
-   data.wallet       — updated wallet snapshot
-   data.transaction  — completed withdrawal record

Error responses:
-   400 — amount missing, non-positive, non-finite, or exceeds maximum; reference too long
-   401 — missing or invalid Bearer token
-   422 — Insufficient balance (balance < requested amount)
-   500 — unexpected server error

Notes:
-   SELECT … FOR UPDATE row-lock prevents concurrent over-draws.
-   Implemented in Phase 4.4. Flutter client service layer implemented in Phase 4.5.

------------------------------------------------------------------------

## Match

### GET /match/queue/status

Return the authenticated player's current matchmaking queue status.
Requires Bearer token.

Response (200):
-   success: true
-   data.inQueue    — true if the player is waiting for a match
-   data.joinedAt   — ISO timestamp of when they joined (null when not queued)
-   data.queueSize  — total players currently in the queue

Notes:
-   Queue join and leave are handled exclusively via Socket.IO
    (find_match / leave_queue events).
-   Implemented in Phase 5.1.

### POST /match/create

Create friend room.

### POST /match/join

Join room.

### POST /match/find

Start matchmaking.

### GET /match/history

Completed matches.

------------------------------------------------------------------------

## Leaderboard

### GET /leaderboard

Top players.

------------------------------------------------------------------------

## Notifications

### GET /notifications

List notifications.

### PUT /notifications/read

Mark notification as read.

------------------------------------------------------------------------

## Settings

### GET /settings

Application settings.

------------------------------------------------------------------------

## Admin

### GET /admin/dashboard

Dashboard statistics.

### GET /admin/users

User list.

### GET /admin/matches

Match list.

------------------------------------------------------------------------

# Response Format

Success

{ success: true, data: {} }

Error

{ success: false, message: "Error message" }

------------------------------------------------------------------------

# Security

-   JWT Authentication
-   HTTPS only
-   Input validation
-   Rate limiting
-   Authorization middleware

------------------------------------------------------------------------

# Version

Current API Version

v1
