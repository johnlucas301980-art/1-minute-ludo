/// Dashboard statistics returned by GET /admin/stats.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.bannedUsers,
    required this.adminUsers,
    required this.totalMatches,
    required this.inProgressMatches,
    required this.totalWalletBalance,
    required this.openTickets,
    required this.inProgressTickets,
  });

  final int    totalUsers;
  final int    activeUsers;
  final int    suspendedUsers;
  final int    bannedUsers;
  final int    adminUsers;
  final int    totalMatches;
  final int    inProgressMatches;
  final double totalWalletBalance;
  final int    openTickets;
  final int    inProgressTickets;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.parse(v);
      throw FormatException('Expected int, got $v');
    }

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.parse(v);
      throw FormatException('Expected num, got $v');
    }

    return AdminStats(
      totalUsers:         toInt(json['total_users']),
      activeUsers:        toInt(json['active_users']),
      suspendedUsers:     toInt(json['suspended_users']),
      bannedUsers:        toInt(json['banned_users']),
      adminUsers:         toInt(json['admin_users']),
      totalMatches:       toInt(json['total_matches']),
      inProgressMatches:  toInt(json['in_progress_matches']),
      totalWalletBalance: toDouble(json['total_wallet_balance']),
      openTickets:        toInt(json['open_tickets']),
      inProgressTickets:  toInt(json['in_progress_tickets']),
    );
  }

  @override
  String toString() =>
      'AdminStats(totalUsers: $totalUsers, openTickets: $openTickets)';
}
