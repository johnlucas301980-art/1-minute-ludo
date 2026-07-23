/**
 * Ludo Game Engine — Phase 6.1 / 6.2.
 *
 * Manages in-memory game state for active matches and handles the `roll_dice`
 * (Phase 6.1) and `move_pawn` (Phase 6.2) socket events.
 *
 * Design decisions:
 *  - All game state is in-memory (Map<matchId, LudoGameState>).  No new DB
 *    tables are required; the existing matches table already stores the final
 *    result (winner_id, status, finished_at).
 *  - The server is the sole source of randomness — clients never supply the
 *    dice value.
 *  - Phase is either `waiting_roll` (player must roll) or `waiting_move`
 *    (player has rolled and must move a pawn).  This prevents double-rolls
 *    and move-without-roll.
 *  - `clearGameState` is called by game_lobby.ts whenever a match finishes
 *    (forfeit, disconnect, or normal completion via win).
 *  - Rolling a 6 grants the same player an extra turn (Phase 6.2).
 *  - Captures send the opponent pawn back to the yard (position 0).
 *    Pawns on safe squares cannot be captured.
 *  - A player wins when all 4 of their pawns reach position 57 (HOME_FINISHED).
 */

import type { Server as SocketIOServer, Socket } from "socket.io";
import { pool } from "../db/index.js";
import { logger } from "../lib/logger.js";
import { createMatchCompletionNotifications } from "../services/notification.service.js";

// ─── Public types ─────────────────────────────────────────────────────────────

export type PawnColor = "red" | "blue" | "green" | "yellow";

export interface ValidMove {
  /** Index of the pawn that can move (0–3). */
  pawnIndex: number;
  /** Current position of the pawn before the move. */
  fromPos: number;
  /** Position the pawn would reach after the move. */
  toPos: number;
}

export interface PawnState {
  /**
   * Colour-relative position:
   *   0       = yard (home base, not yet on the board)
   *   1–51    = shared track
   *   52–56   = home column (colour-specific; cannot be captured)
   *   57      = finished (in the centre)
   */
  position: number;
}

export interface PlayerState {
  userId: string;
  color: PawnColor;
  pawns: [PawnState, PawnState, PawnState, PawnState];
}

export type GamePhase = "waiting_roll" | "waiting_move";

export interface LudoGameState {
  matchId: string;
  players: [PlayerState, PlayerState];
  /** Colour of the player who must act next. */
  currentTurn: PawnColor;
  /** Value produced by the last roll; null before the first roll of a turn. */
  diceValue: number | null;
  /** Moves available after the last roll; empty until `phase === 'waiting_move'`. */
  validMoves: ValidMove[];
  phase: GamePhase;
}

// ─── Board constants ──────────────────────────────────────────────────────────

/** Total cells on the shared track (positions 1–TRACK_LENGTH are on track). */
const TRACK_LENGTH = 52;

/**
 * 0-indexed offset of each colour's entry square measured from Red's entry.
 *
 *   Red    →  0   (enters shared track at absolute position 0)
 *   Blue   → 13   (enters 13 squares ahead of Red)
 *   Green  → 26
 *   Yellow → 39
 */
const COLOR_ENTRY_OFFSET: Record<PawnColor, number> = {
  red: 0,
  blue: 13,
  green: 26,
  yellow: 39,
};

/** The finishing position — a pawn at this position is home. */
const HOME_FINISHED = 57;

/**
 * Safe squares as 0-indexed absolute track positions.
 *
 * Includes the 4 colour entry squares and 4 mid-segment star squares, matching
 * the standard Ludo board layout.  Pawns on safe squares cannot be captured
 * (enforced in Phase 6.2).
 */
export const SAFE_ABSOLUTE_POSITIONS = new Set<number>([
  0,  // Red entry
  8,  // Star
  13, // Blue entry
  21, // Star
  26, // Green entry
  34, // Star
  39, // Yellow entry
  47, // Star
]);

// ─── In-memory store ──────────────────────────────────────────────────────────

/** Active game states keyed by matchId.  Module-level — no singleton class. */
const gameStateMap = new Map<string, LudoGameState>();

// ─── Public state management ──────────────────────────────────────────────────

/**
 * Initialise and store a fresh game state for the given match.
 *
 * Called by game_lobby.ts immediately after emitting `game_start` so that
 * `roll_dice` events can be handled as soon as clients receive that event.
 *
 * @param matchId   - UUID of the match.
 * @param players   - Tuple of both players (userId + assigned colour).
 * @param firstTurn - Colour of the player who rolls first (chosen by game_lobby.ts).
 */
export function createGameState(
  matchId: string,
  players: [
    { userId: string; color: PawnColor },
    { userId: string; color: PawnColor },
  ],
  firstTurn: PawnColor,
): void {
  const makePlayer = (
    p: { userId: string; color: PawnColor },
  ): PlayerState => ({
    userId: p.userId,
    color: p.color,
    pawns: [
      { position: 0 },
      { position: 0 },
      { position: 0 },
      { position: 0 },
    ],
  });

  const state: LudoGameState = {
    matchId,
    players: [makePlayer(players[0]), makePlayer(players[1])],
    currentTurn: firstTurn,
    diceValue: null,
    validMoves: [],
    phase: "waiting_roll",
  };

  gameStateMap.set(matchId, state);
  logger.info({ matchId, firstTurn }, "Game engine: game state created.");
}

/**
 * Retrieve the live game state for a match.
 * Returns `undefined` if the match is not active (not started or already finished).
 */
export function getGameState(matchId: string): LudoGameState | undefined {
  return gameStateMap.get(matchId);
}

/**
 * Remove the game state when a match finishes.
 * Called from game_lobby.ts on forfeit, disconnect, or (Phase 6.2) normal win.
 */
export function clearGameState(matchId: string): void {
  gameStateMap.delete(matchId);
  logger.info({ matchId }, "Game engine: game state cleared.");
}

// ─── Path utilities (used by Phase 6.2 capture detection) ────────────────────

/**
 * Convert a colour-relative shared-track position (1–51) to a 0-indexed
 * absolute track position (0–51).
 *
 * Two pawns of different colours collide (and capture is possible) when their
 * absolute positions are equal and the square is not safe.
 */
export function relativeToAbsolute(
  relPos: number,
  color: PawnColor,
): number {
  return (COLOR_ENTRY_OFFSET[color] + relPos - 1) % TRACK_LENGTH;
}

/**
 * Return `true` if the given 0-indexed absolute track position is a safe square.
 */
export function isAbsoluteSafe(absPos: number): boolean {
  return SAFE_ABSOLUTE_POSITIONS.has(absPos);
}

// ─── Turn helper ──────────────────────────────────────────────────────────────

/**
 * Return the colour of the player who does NOT currently hold the turn.
 * With exactly two players this is a simple toggle.
 */
export function nextPlayerColor(state: LudoGameState): PawnColor {
  const other = state.players.find((p) => p.color !== state.currentTurn);
  if (!other) {
    // Guard — should never happen with a valid two-player state.
    throw new Error("Game engine: cannot determine next player colour.");
  }
  return other.color;
}

// ─── Move computation ─────────────────────────────────────────────────────────

/**
 * Compute all legal pawn moves for `player` given `diceValue`.
 *
 * Rules:
 *  - Position 0 (yard): only a 6 releases the pawn → `toPos = 1`.
 *  - Position 1–56 (on board): advance by `diceValue`; excluded if `toPos > 57`.
 *  - Position 57 (finished): cannot move.
 */
function computeValidMoves(
  player: PlayerState,
  diceValue: number,
): ValidMove[] {
  const moves: ValidMove[] = [];

  for (let i = 0; i < player.pawns.length; i++) {
    const fromPos = player.pawns[i]!.position;

    if (fromPos === HOME_FINISHED) continue; // already home — skip

    if (fromPos === 0) {
      if (diceValue === 6) {
        moves.push({ pawnIndex: i, fromPos: 0, toPos: 1 });
      }
      continue;
    }

    // On the board: advance by dice value if it doesn't overshoot home.
    const toPos = fromPos + diceValue;
    if (toPos <= HOME_FINISHED) {
      moves.push({ pawnIndex: i, fromPos, toPos });
    }
  }

  return moves;
}

// ─── Socket handler internals ─────────────────────────────────────────────────

interface SocketUserData {
  id: string;
  player_id: string;
  fullName: string;
  avatar: string | null;
}

type AuthSocket = Socket & { data: { user: SocketUserData } };

// ─── roll_dice handler ────────────────────────────────────────────────────────

/**
 * Handle the `roll_dice` event emitted by the client.
 *
 * Validation (each failure emits an `error` event and returns early):
 *  - `matchId` must be present in the payload.
 *  - A live game state must exist for this match.
 *  - The calling player must be a participant in the match.
 *  - It must be the calling player's turn (`currentTurn === player.color`).
 *  - The current phase must be `waiting_roll` (not `waiting_move`).
 *
 * On success:
 *  1. Rolls the dice server-side (1–6).
 *  2. Computes valid moves for the rolling player.
 *  3. Emits `dice_rolled { matchId, color, value, validMoves }` to all
 *     players in the room.
 *  4a. If valid moves exist → transitions phase to `waiting_move`.
 *  4b. If no valid moves → passes the turn, updates `currentTurn`, and emits
 *      `turn_changed { matchId, nextTurn }` to all players in the room.
 *
 * @param socket - Authenticated socket of the rolling player.
 * @param io     - Socket.IO server (needed to emit to the full room).
 * @param data   - Raw event payload from the client.
 */
export async function handleRollDice(
  socket: AuthSocket,
  io: SocketIOServer,
  data: unknown,
): Promise<void> {
  const user = socket.data.user;
  const matchId = (data as Record<string, unknown> | null)?.["matchId"];

  if (!matchId || typeof matchId !== "string") {
    socket.emit("error", { message: "roll_dice requires matchId." });
    return;
  }

  const state = gameStateMap.get(matchId);
  if (!state) {
    socket.emit("error", { message: "Game not found or not in progress." });
    return;
  }

  const player = state.players.find((p) => p.userId === user.id);
  if (!player) {
    socket.emit("error", { message: "You are not a player in this match." });
    return;
  }

  if (state.currentTurn !== player.color) {
    socket.emit("error", { message: "It is not your turn." });
    return;
  }

  if (state.phase !== "waiting_roll") {
    socket.emit("error", {
      message: "A pawn move is required before rolling again.",
    });
    return;
  }

  // Server rolls the dice — clients never supply the value.
  const diceValue = Math.floor(Math.random() * 6) + 1;
  const validMoves = computeValidMoves(player, diceValue);

  // Persist the roll to state.
  state.diceValue = diceValue;

  // Notify all players in the room.
  io.to(matchId).emit("dice_rolled", {
    matchId,
    color: player.color,
    value: diceValue,
    validMoves,
  });

  logger.info(
    {
      matchId,
      color: player.color,
      diceValue,
      validMoveCount: validMoves.length,
    },
    "Game engine: dice rolled.",
  );

  if (validMoves.length > 0) {
    // Player must now choose which pawn to move.
    state.validMoves = validMoves;
    state.phase = "waiting_move";
  } else {
    // No legal moves — pass the turn without waiting for a pawn selection.
    const nextTurn = nextPlayerColor(state);
    state.currentTurn = nextTurn;
    state.diceValue = null;
    state.validMoves = [];
    state.phase = "waiting_roll";

    io.to(matchId).emit("turn_changed", { matchId, nextTurn });

    logger.info(
      { matchId, nextTurn },
      "Game engine: no valid moves — turn passed automatically.",
    );
  }
}

// ─── move_pawn handler ────────────────────────────────────────────────────────

/**
 * Handle the `move_pawn` event emitted by the client (Phase 6.2).
 *
 * Validation (each failure emits an `error` event and returns early):
 *  - `matchId` must be present in the payload.
 *  - `pawnIndex` must be an integer 0–3.
 *  - A live game state must exist for this match.
 *  - The calling player must be a participant.
 *  - It must be the calling player's turn (`currentTurn === player.color`).
 *  - The current phase must be `waiting_move` (dice must have been rolled first).
 *  - `pawnIndex` must correspond to a move in `validMoves`.
 *
 * On success:
 *  1. Applies the pawn move to the in-memory state.
 *  2. Checks for a capture: if the pawn lands on a non-safe shared-track square
 *     occupied by an opponent pawn, that pawn is sent back to the yard.
 *  3. Emits `pawn_moved` to all players in the room.
 *  4. Checks for a win: if all 4 of the mover's pawns are at position 57
 *     (HOME_FINISHED), marks the match as finished in the DB, clears game state,
 *     and emits `game_over { matchId, winnerId, reason: 'completed' }`.
 *  5. Otherwise determines the next turn:
 *     - Rolling a 6 grants an extra turn to the same player.
 *     - Any other dice value passes the turn to the opponent.
 *     Resets phase to `waiting_roll` and emits `turn_changed`.
 *
 * Returns `{ matchId }` when the game ends by normal win so the caller
 * (game_lobby.ts) can clean up `activeGameBySocketId`.  Returns `undefined`
 * in all other cases (including early error returns).
 *
 * @param socket - Authenticated socket of the moving player.
 * @param io     - Socket.IO server (needed to emit to the full room).
 * @param data   - Raw event payload from the client.
 */
export async function handleMovePawn(
  socket: AuthSocket,
  io: SocketIOServer,
  data: unknown,
): Promise<{ matchId: string } | undefined> {
  const user = socket.data.user;
  const payload = data as Record<string, unknown> | null;
  const matchId = payload?.["matchId"];
  const pawnIndex = payload?.["pawnIndex"];

  // ── Validation ────────────────────────────────────────────────────────────

  if (!matchId || typeof matchId !== "string") {
    socket.emit("error", { message: "move_pawn requires matchId." });
    return undefined;
  }

  if (
    typeof pawnIndex !== "number" ||
    !Number.isInteger(pawnIndex) ||
    pawnIndex < 0 ||
    pawnIndex > 3
  ) {
    socket.emit("error", { message: "move_pawn requires pawnIndex (0–3)." });
    return undefined;
  }

  const state = gameStateMap.get(matchId);
  if (!state) {
    socket.emit("error", { message: "Game not found or not in progress." });
    return undefined;
  }

  const player = state.players.find((p) => p.userId === user.id);
  if (!player) {
    socket.emit("error", { message: "You are not a player in this match." });
    return undefined;
  }

  if (state.currentTurn !== player.color) {
    socket.emit("error", { message: "It is not your turn." });
    return undefined;
  }

  if (state.phase !== "waiting_move") {
    socket.emit("error", { message: "Roll the dice before moving a pawn." });
    return undefined;
  }

  const move = state.validMoves.find((m) => m.pawnIndex === pawnIndex);
  if (!move) {
    socket.emit("error", {
      message: "That pawn cannot move. Select a valid pawn.",
    });
    return undefined;
  }

  // ── Apply the move ────────────────────────────────────────────────────────

  player.pawns[pawnIndex]!.position = move.toPos;

  // ── Capture detection (shared track only: positions 1–51) ────────────────
  //
  // Positions in the home column (52–56) and finished (57) are colour-specific
  // and can never be reached by an opponent, so no capture check is needed
  // there.  Safe squares are immune to capture regardless.

  let capturedColor: PawnColor | undefined;
  let capturedPawnIndex: number | undefined;

  if (move.toPos >= 1 && move.toPos <= TRACK_LENGTH - 1) {
    const movedAbsPos = relativeToAbsolute(move.toPos, player.color);

    if (!isAbsoluteSafe(movedAbsPos)) {
      const opponent = state.players.find((p) => p.color !== player.color)!;

      for (let i = 0; i < opponent.pawns.length; i++) {
        const oppPawn = opponent.pawns[i]!;
        // Opponent pawns in the yard (0) or home column / finished (52–57)
        // cannot be on the shared track — skip them.
        if (oppPawn.position >= 1 && oppPawn.position <= TRACK_LENGTH - 1) {
          const oppAbsPos = relativeToAbsolute(oppPawn.position, opponent.color);
          if (oppAbsPos === movedAbsPos) {
            oppPawn.position = 0; // sent back to yard
            capturedColor = opponent.color;
            capturedPawnIndex = i;
            logger.info(
              {
                matchId,
                capturedColor: opponent.color,
                capturedPawnIndex: i,
                absPos: movedAbsPos,
              },
              "Game engine: pawn captured.",
            );
            break;
          }
        }
      }
    }
  }

  // ── Emit pawn_moved ───────────────────────────────────────────────────────

  const pawnMovedPayload: Record<string, unknown> = {
    matchId,
    color: player.color,
    pawnIndex,
    toPosition: move.toPos,
  };
  if (capturedColor !== undefined) {
    pawnMovedPayload["capturedColor"] = capturedColor;
    pawnMovedPayload["capturedPawnIndex"] = capturedPawnIndex;
  }

  io.to(matchId).emit("pawn_moved", pawnMovedPayload);

  logger.info(
    {
      matchId,
      color: player.color,
      pawnIndex,
      fromPos: move.fromPos,
      toPos: move.toPos,
      diceValue: state.diceValue,
      capturedColor,
    },
    "Game engine: pawn moved.",
  );

  // ── Win detection: all 4 pawns at HOME_FINISHED (57) ─────────────────────

  const hasWon = player.pawns.every((p) => p.position === HOME_FINISHED);

  if (hasWon) {
    logger.info(
      { matchId, winnerId: player.userId },
      "Game engine: all pawns home — match won.",
    );

    let matchFinished = false;
    try {
      if (pool) {
        const result = await pool.query(
          `UPDATE matches
              SET status      = 'finished',
                  winner_id   = $1,
                  finished_at = NOW()
            WHERE id = $2
              AND status = 'in_progress'`,
          [player.userId, matchId],
        );
        matchFinished = result.rowCount === 1;
      }
    } catch (err) {
      logger.error(
        { err, matchId },
        "Game engine: failed to persist match win to DB.",
      );
    }

    if (matchFinished) {
      try {
        await createMatchCompletionNotifications(matchId, player.userId);
      } catch (err) {
        // Notification persistence must not undo a completed match or suppress
        // the existing game_over event. The event key makes retry safe.
        logger.error(
          { err, matchId, winnerId: player.userId },
          "Game engine: failed to create match completion notifications.",
        );
      }
    }

    clearGameState(matchId);

    io.to(matchId).emit("game_over", {
      matchId,
      winnerId: player.userId,
      reason: "completed",
    });

    // Return matchId so game_lobby.ts can clean up activeGameBySocketId.
    return { matchId };
  }

  // ── Determine next turn ───────────────────────────────────────────────────
  //
  // Rolling a 6 grants an extra turn to the same player.
  // Any other dice value passes the turn to the opponent.

  const getsExtraTurn = state.diceValue === 6;
  const nextTurn = getsExtraTurn ? player.color : nextPlayerColor(state);

  state.currentTurn = nextTurn;
  state.diceValue = null;
  state.validMoves = [];
  state.phase = "waiting_roll";

  io.to(matchId).emit("turn_changed", { matchId, nextTurn });

  logger.info(
    { matchId, nextTurn, getsExtraTurn },
    "Game engine: turn resolved after pawn move.",
  );

  return undefined;
}
