// STEP 1 - REAL MATCHMAKING ARCHITECTURE
// BOT FALLBACK WILL BE IMPLEMENTED IN STEP 2

import 'dart:math';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// The result returned by [OnlineMatchmakingService.checkForPlayers].
enum MatchCheckResult {
  /// No match yet — keep polling.
  waiting,

  /// Enough real players found — stop polling and proceed to the game.
  found,
}

// ---------------------------------------------------------------------------
// Abstract service
// ---------------------------------------------------------------------------

/// Abstraction for the online matchmaking player-search step.
///
/// Callers (e.g. [SearchingPlayersScreen]) poll [checkForPlayers] once per
/// second while the countdown is running.  The service returns
/// [MatchCheckResult.waiting] until a real match is available, then
/// [MatchCheckResult.found].
///
/// The concrete implementation talks to the backend Socket.IO / REST layer.
/// [SimulatedOnlineMatchmakingService] is used in STEP 1 while the full
/// real-time wiring is pending.
abstract class OnlineMatchmakingService {
  /// Check whether enough real players are available for a match.
  ///
  /// Parameters mirror the settings chosen in [GameSetupLobbyScreen] so that
  /// the backend can filter the queue by player count, entry points, etc.
  ///
  /// Returns:
  ///  - [MatchCheckResult.waiting] — still searching.
  ///  - [MatchCheckResult.found]   — match ready; stop polling.
  Future<MatchCheckResult> checkForPlayers({
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
// Simulated implementation (STEP 1)
// ---------------------------------------------------------------------------

/// Temporary implementation used in STEP 1.
///
/// Behaves exactly like a real matchmaking service from the caller's
/// perspective, but resolves locally without a network call.
///
/// Behaviour:
///  - Returns [MatchCheckResult.waiting] for a random number of polls
///    between [_minPollsBeforeMatch] and [_maxPollsBeforeMatch] (inclusive).
///  - Returns [MatchCheckResult.found] on the next call after that threshold,
///    then remains [MatchCheckResult.found] until [dispose] is called.
///
/// The random threshold simulates real players joining the queue at different
/// times so that the UI can be developed and tested against a realistic flow.
class SimulatedOnlineMatchmakingService implements OnlineMatchmakingService {
  SimulatedOnlineMatchmakingService({Random? random})
      : _random = random ?? Random() {
    // Pick a random threshold once per service lifetime so successive polls
    // within the same search session are deterministic.
    _matchAfterPolls =
        _minPollsBeforeMatch + _random.nextInt(_maxPollsBeforeMatch - _minPollsBeforeMatch + 1);
  }

  // Simulated match found between 4 and 12 seconds after searching starts.
  static const int _minPollsBeforeMatch = 4;
  static const int _maxPollsBeforeMatch = 12;

  final Random _random;
  late final int _matchAfterPolls;
  int _pollCount = 0;
  bool _disposed = false;

  @override
  Future<MatchCheckResult> checkForPlayers({
    required int players,
    required int entryPoints,
    required int pawnCount,
    required String boardColor,
  }) async {
    if (_disposed) return MatchCheckResult.waiting;

    _pollCount++;
    if (_pollCount >= _matchAfterPolls) {
      return MatchCheckResult.found;
    }
    return MatchCheckResult.waiting;
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
