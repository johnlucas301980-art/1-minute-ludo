/// Represents the player's current matchmaking queue status as returned by
/// GET /api/match/queue/status.
class QueueStatus {
  const QueueStatus({
    required this.inQueue,
    required this.queueSize,
    this.joinedAt,
  });

  /// Whether the authenticated player is currently waiting for a match.
  final bool inQueue;

  /// Total number of players currently in the matchmaking queue.
  final int queueSize;

  /// ISO-8601 timestamp of when the player joined the queue.
  /// Null when [inQueue] is false.
  final String? joinedAt;

  factory QueueStatus.fromJson(Map<String, dynamic> json) {
    return QueueStatus(
      inQueue:   json['inQueue']   as bool,
      queueSize: json['queueSize'] as int,
      joinedAt:  json['joinedAt']  as String?,
    );
  }

  @override
  String toString() =>
      'QueueStatus(inQueue: $inQueue, queueSize: $queueSize, joinedAt: $joinedAt)';
}
