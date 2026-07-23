---
name: Match status schema mismatch
description: Pre-existing database/application mismatch that blocks real gameplay verification.
---

The current database constraint for match status allows `waiting`, `active`, `finished`, and `cancelled`, while the existing game-start path writes `in_progress`. As a result, real matches fail before `game_start` with PostgreSQL constraint error 23514.

**Why:** The mismatch prevents any normal completed match from reaching the gameplay engine, so completion hooks cannot be verified through the real socket flow.

**How to apply:** Treat this as pre-existing gameplay infrastructure work. Do not alter it as part of notification phases; resolve it separately before relying on end-to-end match-completion tests.