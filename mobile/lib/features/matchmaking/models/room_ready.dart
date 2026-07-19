/// Payload of the `room_ready` Socket.IO event.
///
/// Emitted by the server to all players in a room once every matched player
/// has emitted `join_room`.  Signals that the game lobby is fully populated
/// and gameplay (Phase 6) can begin.
class RoomReady {
  const RoomReady({required this.matchId});

  /// UUID of the match that is ready to start.
  final String matchId;

  factory RoomReady.fromJson(Map<String, dynamic> json) =>
      RoomReady(matchId: json['matchId'] as String);

  @override
  String toString() => 'RoomReady(matchId: $matchId)';
}
