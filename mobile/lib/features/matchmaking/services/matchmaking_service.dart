import 'dart:async';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/match_found.dart';
import '../models/queue_status.dart';
import 'socket_client.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when a matchmaking operation fails for a reason other than session
/// expiry (e.g. server error, network failure, unexpected socket event).
class MatchmakingException implements Exception {
  const MatchmakingException(this.message);
  final String message;

  @override
  String toString() => 'MatchmakingException: $message';
}

// ---------------------------------------------------------------------------
// MatchmakingService
// ---------------------------------------------------------------------------

/// Manages the matchmaking flow for 1 Minute Ludo.
///
/// Responsibilities:
///  - [getQueueStatus]  — REST GET /api/match/queue/status (read-only poll).
///  - [joinQueue]       — connect the socket and emit `find_match`.
///  - [leaveQueue]      — emit `leave_queue` and disconnect the socket.
///  - [onMatchFound]    — a [Stream] that emits one [MatchFound] event when
///                        the server pairs the player with an opponent.
///  - [dispose]         — close the stream controller and disconnect.
///
/// Architecture:
///  - Queue join/leave happen exclusively via Socket.IO; REST is read-only.
///  - [ApiClient] is injected for REST calls; [SocketClient] is injected for
///    Socket.IO calls. Neither has defaults — caller must provide both.
///  - [SessionExpiredException] is re-thrown from any REST call that returns
///    401, or from [joinQueue] when the socket connection is refused with an
///    "unauthorized" error (expired/absent JWT).
///
/// Usage:
/// ```dart
/// final service = MatchmakingService(
///   apiClient:    ApiClient(tokenStorage: storage, httpClient: http.Client()),
///   socketClient: SocketClient(tokenProvider: storage.getAccessToken),
/// );
///
/// // Listen for match_found before joining:
/// service.onMatchFound.listen((event) {
///   Navigator.pushNamed(context, '/game', arguments: event);
/// });
///
/// await service.joinQueue();
///
/// // …later, if player cancels:
/// await service.leaveQueue();
/// service.dispose();
/// ```
class MatchmakingService {
  MatchmakingService({
    required ApiClient apiClient,
    required SocketClient socketClient,
  })  : _api    = apiClient,
        _socket = socketClient;

  final ApiClient    _api;
  final SocketClient _socket;

  final StreamController<MatchFound> _matchFoundController =
      StreamController<MatchFound>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Stream that emits a single [MatchFound] event when the server pairs this
  /// player with an opponent.
  ///
  /// Subscribe BEFORE calling [joinQueue] to avoid missing the event.
  Stream<MatchFound> get onMatchFound => _matchFoundController.stream;

  // ── REST — read-only ───────────────────────────────────────────────────────

  /// Fetch the player's current matchmaking queue status from the server.
  ///
  /// Returns a [QueueStatus] describing whether the player is currently in
  /// the queue, when they joined, and how many players are waiting.
  ///
  /// Throws:
  ///  - [SessionExpiredException] on 401 (token absent or expired).
  ///  - [MatchmakingException] on 5xx or unexpected response.
  Future<QueueStatus> getQueueStatus() async {
    try {
      final response = await _api.authenticatedRequest('GET', '/match/queue/status');

      final body = response['data'] as Map<String, dynamic>?;
      if (body == null) {
        throw const MatchmakingException('Queue status response missing data field.');
      }

      return QueueStatus.fromJson(body);
    } on SessionExpiredException {
      rethrow;
    } on ApiException catch (e) {
      throw MatchmakingException('Failed to fetch queue status: ${e.message}');
    }
  }

  // ── Socket.IO ──────────────────────────────────────────────────────────────

  /// Connect to the Socket.IO server and emit `find_match`.
  ///
  /// If no opponent is waiting, the server places the player in the queue
  /// and emits `queue_joined`.  If an opponent is already waiting, both
  /// players immediately receive `match_found` via [onMatchFound].
  ///
  /// Calling [joinQueue] while already connected is safe — socket.io
  /// handles the reconnect transparently.
  ///
  /// Throws:
  ///  - [SessionExpiredException] when the socket connection is refused
  ///    because the JWT is absent, expired, or invalid.
  ///  - [MatchmakingException] for any other connection failure.
  Future<void> joinQueue() async {
    try {
      await _socket.connect();
    } on SocketConnectionException catch (e) {
      // The server rejects all unauthenticated connections with "unauthorized".
      if (e.message.toLowerCase().contains('unauthorized') ||
          e.message.toLowerCase().contains('no access token')) {
        throw SessionExpiredException();
      }
      throw MatchmakingException('Socket connection failed: ${e.message}');
    }

    // Register match_found handler (idempotent — safe to call again on rejoin).
    _socket.off('match_found'); // clear any stale handler first
    _socket.on('match_found', _handleMatchFound);

    _socket.emit('find_match');
  }

  /// Emit `leave_queue` and disconnect the socket.
  ///
  /// Safe to call even when not in the queue (the server handles it
  /// idempotently). Does NOT throw if the socket is not connected.
  Future<void> leaveQueue() async {
    if (_socket.isConnected) {
      _socket.emit('leave_queue');
    }
    _socket.off('match_found');
    _socket.disconnect();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Release all resources: close the stream controller and disconnect.
  ///
  /// After calling [dispose], this instance must not be used again.
  void dispose() {
    _socket.off('match_found');
    _socket.dispose();
    if (!_matchFoundController.isClosed) {
      _matchFoundController.close();
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _handleMatchFound(dynamic data) {
    if (_matchFoundController.isClosed) return;

    try {
      final json = (data as Map<dynamic, dynamic>).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      _matchFoundController.add(MatchFound.fromJson(json));
    } catch (_) {
      // Silently drop malformed events; the listener should not crash.
    }
  }
}
