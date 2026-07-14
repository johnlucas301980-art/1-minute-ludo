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

Upload avatar.

### PUT /profile/password

Change password.

------------------------------------------------------------------------

## Wallet

### GET /wallet

Current wallet balance.

### GET /wallet/history

Transaction history.

------------------------------------------------------------------------

## Match

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
