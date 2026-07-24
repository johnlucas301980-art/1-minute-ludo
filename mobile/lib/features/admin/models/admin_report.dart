/// Aggregated administrator report — Phase 10.4.

class AdminReport {
  const AdminReport({
    required this.from,
    required this.to,
    required this.users,
    required this.matches,
    required this.wallets,
    required this.transactions,
    required this.support,
  });

  final DateTime from;
  final DateTime to;
  final AdminReportUsers users;
  final AdminReportMatches matches;
  final AdminReportWallets wallets;
  final AdminReportTransactions transactions;
  final AdminReportSupport support;

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    return AdminReport(
      from: DateTime.parse(json['from'] as String).toLocal(),
      to: DateTime.parse(json['to'] as String).toLocal(),
      users: AdminReportUsers.fromJson(json['users'] as Map<String, dynamic>),
      matches: AdminReportMatches.fromJson(json['matches'] as Map<String, dynamic>),
      wallets: AdminReportWallets.fromJson(json['wallets'] as Map<String, dynamic>),
      transactions: AdminReportTransactions.fromJson(
        json['transactions'] as Map<String, dynamic>,
      ),
      support: AdminReportSupport.fromJson(json['support'] as Map<String, dynamic>),
    );
  }
}

int _intValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

double _doubleValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

class AdminReportUsers {
  const AdminReportUsers({
    required this.total,
    required this.newUsers,
    required this.active,
    required this.suspended,
    required this.banned,
  });
  final int total;
  final int newUsers;
  final int active;
  final int suspended;
  final int banned;

  factory AdminReportUsers.fromJson(Map<String, dynamic> json) => AdminReportUsers(
        total: _intValue(json, 'total'),
        newUsers: _intValue(json, 'new_users'),
        active: _intValue(json, 'active'),
        suspended: _intValue(json, 'suspended'),
        banned: _intValue(json, 'banned'),
      );
}

class AdminReportMatches {
  const AdminReportMatches({
    required this.total,
    required this.waiting,
    required this.inProgress,
    required this.finished,
    required this.cancelled,
  });
  final int total;
  final int waiting;
  final int inProgress;
  final int finished;
  final int cancelled;

  factory AdminReportMatches.fromJson(Map<String, dynamic> json) => AdminReportMatches(
        total: _intValue(json, 'total'),
        waiting: _intValue(json, 'waiting'),
        inProgress: _intValue(json, 'in_progress'),
        finished: _intValue(json, 'finished'),
        cancelled: _intValue(json, 'cancelled'),
      );
}

class AdminReportWallets {
  const AdminReportWallets({
    required this.walletCount,
    required this.totalPoints,
    required this.totalDeposit,
    required this.totalWithdraw,
  });
  final int walletCount;
  final double totalPoints;
  final double totalDeposit;
  final double totalWithdraw;

  factory AdminReportWallets.fromJson(Map<String, dynamic> json) => AdminReportWallets(
        walletCount: _intValue(json, 'wallet_count'),
        totalPoints: _doubleValue(json, 'total_points'),
        totalDeposit: _doubleValue(json, 'total_deposit'),
        totalWithdraw: _doubleValue(json, 'total_withdraw'),
      );
}

class AdminReportTransactions {
  const AdminReportTransactions({
    required this.total,
    required this.deposit,
    required this.withdraw,
    required this.reward,
    required this.entryFee,
    required this.refund,
  });
  final int total;
  final double deposit;
  final double withdraw;
  final double reward;
  final double entryFee;
  final double refund;

  factory AdminReportTransactions.fromJson(Map<String, dynamic> json) =>
      AdminReportTransactions(
        total: _intValue(json, 'total'),
        deposit: _doubleValue(json, 'deposit'),
        withdraw: _doubleValue(json, 'withdraw'),
        reward: _doubleValue(json, 'reward'),
        entryFee: _doubleValue(json, 'entry_fee'),
        refund: _doubleValue(json, 'refund'),
      );
}

class AdminReportSupport {
  const AdminReportSupport({
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.closed,
  });
  final int open;
  final int inProgress;
  final int resolved;
  final int closed;

  factory AdminReportSupport.fromJson(Map<String, dynamic> json) => AdminReportSupport(
        open: _intValue(json, 'open'),
        inProgress: _intValue(json, 'in_progress'),
        resolved: _intValue(json, 'resolved'),
        closed: _intValue(json, 'closed'),
      );
}