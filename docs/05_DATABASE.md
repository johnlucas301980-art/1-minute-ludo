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

Stores current player balance.

Fields:

-   id
-   user_id
-   points
-   total_deposit
-   total_withdraw
-   updated_at

Relationship:

users (1) → wallets (1)

------------------------------------------------------------------------

## transactions

Stores wallet history.

Fields:

-   id
-   user_id
-   type
-   amount
-   status
-   reference
-   created_at

Types:

-   Deposit
-   Withdraw
-   Reward
-   Entry Fee
-   Refund

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
