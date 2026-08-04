// STEP 1 - REAL MATCHMAKING ARCHITECTURE
// STEP 2 - BOT FALLBACK ADDED

import 'dart:math';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// The outcome of a single [OnlineMatchmakingService.checkForPlayers] poll.
enum MatchCheckResult {
  /// Not enough real players yet — keep polling.
  waiting,

  /// Enough real players found — stop polling and proceed to the game.
  found,
}

/// Full status returned by [OnlineMatchmakingService.checkForPlayers].
///
/// Carries both the poll outcome and a count of real players already matched
/// so the caller can calculate how many BOT slots are needed on timeout.
class MatchCheckStatus {
  const MatchCheckStatus({
    required this.result,
    required this.realPlayersFound,
  });

  /// Whether the match is complete ([MatchCheckResult.found]) or still
  /// searching ([MatchCheckResult.waiting]).
  final MatchCheckResult result;

  /// Number of real (non-bot) players found so far, excluding the local
  /// player.  When [result] is [MatchCheckResult.found] this equals the
  /// number of opponent slots — i.e. `players - 1`.
  final int realPlayersFound;
}

// ---------------------------------------------------------------------------
// Abstract service
// ---------------------------------------------------------------------------

/// Abstraction for the online matchmaking player-search step.
///
/// Callers (e.g. [SearchingPlayersScreen]) poll [checkForPlayers] once per
/// second while the countdown is running.  The service returns a
/// [MatchCheckStatus] with [MatchCheckResult.waiting] until a real match is
/// available, then [MatchCheckResult.found].
///
/// [MatchCheckStatus.realPlayersFound] is updated on every poll so the
/// screen can fill remaining slots with BOTs on timeout (STEP 2).
///
/// The concrete production implementation talks to the backend Socket.IO /
/// REST layer.  [SimulatedOnlineMatchmakingService] is used while the full
/// real-time wiring is pending.
abstract class OnlineMatchmakingService {
  /// Check whether enough real players are available for a match.
  ///
  /// Parameters mirror the settings chosen in [GameSetupLobbyScreen] so that
  /// the backend can filter the queue by player count, entry points, etc.
  ///
  /// Returns a [MatchCheckStatus] with:
  ///  - [MatchCheckResult.waiting] — still searching; [realPlayersFound]
  ///    reflects how many opponents have joined so far.
  ///  - [MatchCheckResult.found]   — all opponent slots filled with real
  ///    players; stop polling immediately.
  Future<MatchCheckStatus> checkForPlayers({
    required int players,
    required int entryPoints,
    required int pawnCount,
    required String boardColor,
  });

  /// Release any resources (open sockets, streams, timers) held by this
  /// service instance.
  void dispose();
}

// ---------------------------------------------------------------------------
// Simulated implementation
// ---------------------------------------------------------------------------

/// Temporary implementation used while the real backend matchmaking wiring
/// is pending.
///
/// Behaves exactly like a real matchmaking service from the caller's
/// perspective, but resolves locally without a network call.
///
/// Behaviour:
///  - Simulates real opponents joining one slot at a time; a new real player
///    is added every [_pollsPerPlayer] seconds.
///  - Returns [MatchCheckResult.found] once [realPlayersFound] reaches
///    `players - 1` (all opponent slots filled), which happens at most after
///    [_matchAfterPolls] polls (random threshold between
///    [_minPollsBeforeMatch] and [_maxPollsBeforeMatch]).
///  - The random threshold ensures the UI can be exercised against both
///    "fast match" and "bot fallback" code paths during development.
class SimulatedOnlineMatchmakingService implements OnlineMatchmakingService {
  SimulatedOnlineMatchmakingService({Random? random})
      : _random = random ?? Random() {
    // Pick a random threshold once per service lifetime so successive polls
    // within the same search session are deterministic.
    _matchAfterPolls =
        _minPollsBeforeMatch +
        _random.nextInt(_maxPollsBeforeMatch - _minPollsBeforeMatch + 1);
  }

  // Simulated match found between 4 and 12 seconds after searching starts.
  static const int _minPollsBeforeMatch = 4;
  static const int _maxPollsBeforeMatch = 12;

  // One simulated real player joins every N polls (approx. every N seconds).
  static const int _pollsPerPlayer = 5;

  final Random _random;
  late final int _matchAfterPolls;
  int  _pollCount = 0;
  bool _disposed  = false;

  @override
  Future<MatchCheckStatus> checkForPlayers({
    required int players,
    required int entryPoints,
    required int pawnCount,
    required String boardColor,
  }) async {
    if (_disposed) {
      return const MatchCheckStatus(
        result: MatchCheckResult.waiting,
        realPlayersFound: 0,
      );
    }

    _pollCount++;

    final slotsNeeded = players - 1; // opponent slots (excludes local player)

    if (_pollCount >= _matchAfterPolls) {
      // All opponent slots filled with real players — match is ready.
      return MatchCheckStatus(
        result: MatchCheckResult.found,
        realPlayersFound: slotsNeeded,
      );
    }

    // Simulate opponents joining gradually: one new real player every
    // _pollsPerPlayer seconds, capped at slotsNeeded - 1 (leave at least
    // one slot for the threshold to fill so the "found" path is reached).
    final simulatedReal =
        (_pollCount ~/ _pollsPerPlayer).clamp(0, (slotsNeeded - 1).clamp(0, slotsNeeded));

    return MatchCheckStatus(
      result: MatchCheckResult.waiting,
      realPlayersFound: simulatedReal,
    );
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
