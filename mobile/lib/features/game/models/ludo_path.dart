/// Board and path coordinate constants for the Ludo game engine.
///
/// All values mirror `backend/src/socket/game_engine.ts` exactly.
/// No rendering logic lives here — this file is pure coordinate data used by
/// game-logic layers and, later, the board widget.
///
/// ## Position encoding (colour-relative)
///
/// Every pawn position is expressed in *colour-relative* terms:
///
/// | Value | Meaning                                        |
/// |-------|------------------------------------------------|
/// | 0     | Yard — home base, not yet on the board         |
/// | 1–51  | Shared track                                   |
/// | 52–56 | Home column (colour-specific, no captures)     |
/// | 57    | Finished — pawn is in the centre ([homeFinished]) |
///
/// Absolute track positions (0-indexed, 0–51) are used for cross-colour
/// collision and capture detection.  Convert with [relativeToAbsolute].

// ─── Shared-track constants ───────────────────────────────────────────────────

/// Total number of cells on the shared track.
///
/// Shared-track colour-relative positions run from 1 to 51.
/// Absolute positions run from 0 to 51.
///
/// Mirrors `TRACK_LENGTH` in `game_engine.ts`.
const int trackLength = 52;

/// Colour-relative position a pawn holds when it is still in the yard and has
/// not yet entered the board.
///
/// A pawn at [yardPosition] can only be released by rolling a 6.
const int yardPosition = 0;

/// Colour-relative position a pawn holds once it has finished the race.
///
/// A player wins when all four of their pawns are at [homeFinished].
///
/// Mirrors `HOME_FINISHED` in `game_engine.ts`.
const int homeFinished = 57;

/// First colour-relative position on the shared track (entry from the yard).
///
/// A pawn moves from [yardPosition] (0) to [trackEntryPosition] (1) when
/// released by a roll of 6.
const int trackEntryPosition = 1;

/// First colour-relative position of the home column.
///
/// Positions [homeColumnStart]–[homeColumnEnd] (52–56) are colour-specific
/// and cannot be entered or captured by an opponent pawn.
const int homeColumnStart = 52;

/// Last colour-relative position of the home column before finishing.
const int homeColumnEnd = 56;

// ─── Colour entry offsets ─────────────────────────────────────────────────────

/// 0-indexed offset of each colour's entry square on the shared track,
/// measured from Red's entry square (absolute position 0).
///
/// Used by [relativeToAbsolute] to convert colour-relative positions to
/// absolute positions for cross-colour collision checks.
///
/// Mirrors `COLOR_ENTRY_OFFSET` in `game_engine.ts`.
///
/// | Colour | Absolute entry |
/// |--------|---------------|
/// | red    | 0             |
/// | blue   | 13            |
/// | green  | 26            |
/// | yellow | 39            |
const Map<String, int> colorEntryOffset = {
  'red':    0,
  'blue':   13,
  'green':  26,
  'yellow': 39,
};

// ─── Safe squares ─────────────────────────────────────────────────────────────

/// Safe squares as 0-indexed absolute track positions.
///
/// Includes the four colour entry squares and four mid-segment star squares,
/// matching the standard Ludo board layout.  Pawns on safe squares cannot be
/// captured by an opponent.
///
/// Mirrors `SAFE_ABSOLUTE_POSITIONS` in `game_engine.ts`.
const Set<int> safeAbsolutePositions = {
  0,  // Red entry
  8,  // Star
  13, // Blue entry
  21, // Star
  26, // Green entry
  34, // Star
  39, // Yellow entry
  47, // Star
};

// ─── Path utilities ───────────────────────────────────────────────────────────

/// Convert a colour-relative shared-track position (1–51) to a 0-indexed
/// absolute track position (0–51).
///
/// Two pawns of different colours collide — and capture is possible — when
/// their absolute positions are equal and the square is not safe (see
/// [isAbsoluteSafe]).
///
/// [relPos] must be in the range 1–51 (shared track only).
/// [color] must be one of `'red'`, `'blue'`, `'green'`, `'yellow'`.
///
/// Mirrors `relativeToAbsolute` in `game_engine.ts`.
int relativeToAbsolute(int relPos, String color) {
  final offset = colorEntryOffset[color];
  assert(offset != null, 'relativeToAbsolute: unknown color "$color"');
  return ((offset ?? 0) + relPos - 1) % trackLength;
}

/// Return `true` if the given 0-indexed absolute track position is a safe
/// square (i.e. immune to pawn capture).
///
/// Mirrors `isAbsoluteSafe` in `game_engine.ts`.
bool isAbsoluteSafe(int absPos) => safeAbsolutePositions.contains(absPos);
