/// Models for admin match monitoring — Phase 10.3.

// ─── AdminMatchPlayer ────────────────────────────────────────────────────────

/// A player entry embedded inside an [AdminMatch].
class AdminMatchPlayer {
  const AdminMatchPlayer({
    required this.userId,
    required this.playerId,
    required this.fullName,
    required this.color,
    this.finalRank,
  });

  final String userId;
  final String playerId;
  final String fullName;
  final String color;
  final int?   finalRank;

  factory AdminMatchPlayer.fromJson(Map<String, dynamic> json) {
    final userId   = json['user_id'];
    final playerId = json['player_id'];
    final fullName = json['full_name'];
    final color    = json['color'];
    if (userId is! String || playerId is! String ||
        fullName is! String || color is! String) {
      throw const FormatException('Invalid admin match player payload.');
    }
    return AdminMatchPlayer(
      userId:    userId,
      playerId:  playerId,
      fullName:  fullName,
      color:     color,
      finalRank: (json['final_rank'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminMatchPlayer &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'AdminMatchPlayer(userId: $userId, playerId: $playerId, color: $color)';
}

// ─── AdminMatch ───────────────────────────────────────────────────────────────

/// A match record as returned by the admin API.
class AdminMatch {
  const AdminMatch({
    required this.id,
    required this.roomCode,
    required this.mode,
    required this.status,
    required this.entryPoints,
    required this.playerCount,
    required this.createdAt,
    required this.players,
    this.winnerId,
    this.winnerPlayerId,
    this.winnerFullName,
    this.startedAt,
    this.finishedAt,
  });

  final String   id;
  final String   roomCode;
  final String   mode;
  final String   status;
  final double   entryPoints;
  final int      playerCount;
  final DateTime createdAt;
  final List<AdminMatchPlayer> players;

  final String?  winnerId;
  final String?  winnerPlayerId;
  final String?  winnerFullName;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  factory AdminMatch.fromJson(Map<String, dynamic> json) {
    final id         = json['id'];
    final roomCode   = json['room_code'];
    final mode       = json['mode'];
    final status     = json['status'];
    final entryPoints = json['entry_points'];
    final playerCount = json['player_count'];
    final createdAt  = json['created_at'];

    if (id is! String || roomCode is! String || mode is! String ||
        status is! String || createdAt is! String) {
      throw const FormatException('Invalid admin match payload.');
    }

    final rawPlayers = json['players'];

    return AdminMatch(
      id:           id,
      roomCode:     roomCode,
      mode:         mode,
      status:       status,
      entryPoints:  (entryPoints is num)
          ? entryPoints.toDouble()
          : double.tryParse(entryPoints?.toString() ?? '0') ?? 0.0,
      playerCount:  (playerCount as num?)?.toInt() ?? 0,
      createdAt:    DateTime.parse(createdAt).toLocal(),
      players:      rawPlayers is List
          ? rawPlayers
              .whereType<Map<String, dynamic>>()
              .map(AdminMatchPlayer.fromJson)
              .toList()
          : const [],
      winnerId:       json['winner_id'] as String?,
      winnerPlayerId: json['winner_player_id'] as String?,
      winnerFullName: json['winner_full_name'] as String?,
      startedAt: json['started_at'] is String
          ? DateTime.parse(json['started_at'] as String).toLocal()
          : null,
      finishedAt: json['finished_at'] is String
          ? DateTime.parse(json['finished_at'] as String).toLocal()
          : null,
    );
  }

  /// Returns true when an admin can force-cancel this match.
  bool get isCancellable => status == 'waiting' || status == 'in_progress';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminMatch && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AdminMatch(id: $id, roomCode: $roomCode, status: $status)';
}

// ─── AdminMatchEvent ──────────────────────────────────────────────────────────

/// A single event in the derived match timeline.
class AdminMatchEvent {
  const AdminMatchEvent({
    required this.type,
    required this.description,
    required this.timestamp,
    this.meta,
  });

  final String   type;
  final String   description;
  final DateTime timestamp;
  final Map<String, dynamic>? meta;

  factory AdminMatchEvent.fromJson(Map<String, dynamic> json) {
    final type        = json['type'];
    final description = json['description'];
    final timestamp   = json['timestamp'];

    if (type is! String || description is! String || timestamp is! String) {
      throw const FormatException('Invalid admin match event payload.');
    }

    return AdminMatchEvent(
      type:        type,
      description: description,
      timestamp:   DateTime.parse(timestamp).toLocal(),
      meta:        json['meta'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminMatchEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(type, timestamp);

  @override
  String toString() => 'AdminMatchEvent(type: $type, timestamp: $timestamp)';
}
