# 05_DATABASE.md

# DATABASE DESIGN

## Database

Engine: PostgreSQL

Purpose: Store all persistent application data securely.

------------------------------------------------------------------------

# Main Tables

## users

Stores player accounts.

Fields:

-   id
-   player_id (auto generated, unique)
-   full_name
-   email
-   mobile
-   password_hash
-   google_id
-   country
-   avatar
-   status
-   created_at
-   updated_at

------------------------------------------------------------------------

## wallets

Stores current player balance. One row per user (UNIQUE on user_id).
Implemented in Phase 4.1 (migration 0004).

Fields:

-   id             — UUID PK
-   user_id        — UUID FK → users(id) ON DELETE CASCADE, UNIQUE
-   points         — NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK >= 0
-   total_deposit  — NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK >= 0
-   total_withdraw — NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK >= 0
-   updated_at     — TIMESTAMPTZ, maintained by trigger

Relationship:

users (1) → wallets (1)

------------------------------------------------------------------------

## transactions

Immutable ledger of all wallet movements — rows are never updated or
deleted. Implemented in Phase 4.1 (migration 0005).

Fields:

-   id        — UUID PK
-   user_id   — UUID FK → users(id) ON DELETE CASCADE
-   type      — VARCHAR(20) CHECK IN (deposit, withdraw, reward, entry_fee, refund)
-   amount    — NUMERIC(18,2)
-   status    — VARCHAR(20) DEFAULT 'completed' CHECK IN (pending, completed, failed, reversed)
-   reference — TEXT (optional external reference)
-   created_at — TIMESTAMPTZ

Types:

-   deposit
-   withdraw
-   reward
-   entry_fee
-   refund

------------------------------------------------------------------------

## matches

Stores match information.

Fields:

-   id
-   room_code
-   mode
-   entry_points
-   player_count
-   winner_id
-   status
-   started_at
-   finished_at

------------------------------------------------------------------------

## match_players

Stores players inside each match.

Fields:

-   id
-   match_id
-   user_id
-   color
-   pawn_count
-   final_rank
-   earned_points

------------------------------------------------------------------------

## game_history

Stores completed game results.

Fields:

-   id
-   match_id
-   winner_id
-   duration
-   total_moves
-   created_at

------------------------------------------------------------------------

## leaderboard

Stores ranking information.

Fields:

-   id
-   user_id
-   wins
-   losses
-   win_rate
-   total_points

------------------------------------------------------------------------

## notifications

Stores user notifications.

Fields:

-   id
-   user_id
-   title
-   message
-   is_read
-   created_at

------------------------------------------------------------------------

## settings

Stores application settings.

Fields:

-   id
-   key
-   value

------------------------------------------------------------------------

# Relationships

users ├── wallets ├── transactions ├── leaderboard ├── notifications └──
match_players

matches ├── match_players └── game_history

------------------------------------------------------------------------

# Rules

-   Use UUID or BIGINT primary keys consistently.
-   Foreign keys must be enforced.
-   Never delete financial records.
-   Use soft delete where appropriate.
-   Store passwords only as hashes.
-   Index frequently queried columns.
-   Use database transactions for wallet and match operations.

------------------------------------------------------------------------

# Future Expansion

The schema is designed to support:

-   New game modes
-   Tournaments
-   Referral system
-   Rewards
-   Multiple currencies
-   Admin analytics
