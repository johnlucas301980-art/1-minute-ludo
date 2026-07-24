import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/admin_stats.dart';
import '../models/admin_ticket.dart';
import '../models/admin_user.dart';
import '../models/audit_log_entry.dart';

/// Provides access to the admin backend endpoints.
///
/// All methods require an authenticated admin session. A [ApiException] with
/// status 403 is thrown when the authenticated user is not an admin.
class AdminService {
  AdminService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<AdminStats> getStats() async {
    final response = await _api.authenticatedRequest('GET', '/admin/stats');
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['stats'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Stats response missing stats object.');
    }
    return AdminStats.fromJson(raw);
  }

  // ─── Users ────────────────────────────────────────────────────────────────

  /// Returns a paginated list of all users.
  /// Phase 10.2 adds [search] — searches across name, email, player ID, mobile.
  Future<({List<AdminUser> users, int total})> listUsers({
    int limit  = 20,
    int offset = 0,
    String? status,
    String? role,
    String? search,
  }) async {
    final query = StringBuffer('/admin/users?limit=$limit&offset=$offset');
    if (status != null && status.isNotEmpty) query.write('&status=$status');
    if (role   != null && role.isNotEmpty)   query.write('&role=$role');
    if (search != null && search.isNotEmpty) {
      query.write('&search=${Uri.encodeQueryComponent(search)}');
    }

    final response = await _api.authenticatedRequest('GET', query.toString());
    final data     = response['data'] as Map<String, dynamic>?;
    final rawUsers = data?['users'];
    if (rawUsers is! List) {
      throw const FormatException('Users response missing users array.');
    }

    final pagination = data?['pagination'] as Map<String, dynamic>?;
    final total = (pagination?['total'] as num?)?.toInt() ?? 0;

    return (
      users: rawUsers.whereType<Map<String, dynamic>>().map(AdminUser.fromJson).toList(),
      total: total,
    );
  }

  /// Returns a single user by their UUID.
  Future<AdminUser?> getUserById(String userId) async {
    try {
      final response = await _api.authenticatedRequest('GET', '/admin/users/$userId');
      final data = response['data'] as Map<String, dynamic>?;
      final raw  = data?['user'];
      if (raw is! Map<String, dynamic>) return null;
      return AdminUser.fromJson(raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Generic status update. For ban/unban prefer [banUser]/[unbanUser].
  Future<AdminUser> updateUserStatus(String userId, String status) async {
    final response = await _api.authenticatedRequest(
      'PATCH',
      '/admin/users/$userId/status',
      body: {'status': status},
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['user'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Update user status response missing user.');
    }
    return AdminUser.fromJson(raw);
  }

  /// Generic role update. For promote/demote prefer [promoteUser]/[demoteUser].
  Future<AdminUser> updateUserRole(String userId, String role) async {
    final response = await _api.authenticatedRequest(
      'PATCH',
      '/admin/users/$userId/role',
      body: {'role': role},
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['user'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Update user role response missing user.');
    }
    return AdminUser.fromJson(raw);
  }

  // ─── Phase 10.2 — Dedicated player actions ────────────────────────────────

  /// Bans the player (sets status = banned) and records an audit log entry.
  Future<AdminUser> banUser(String userId) async {
    final response = await _api.authenticatedRequest(
      'POST',
      '/admin/users/$userId/ban',
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['user'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Ban user response missing user.');
    }
    return AdminUser.fromJson(raw);
  }

  /// Unbans the player (sets status = active) and records an audit log entry.
  Future<AdminUser> unbanUser(String userId) async {
    final response = await _api.authenticatedRequest(
      'POST',
      '/admin/users/$userId/unban',
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['user'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Unban user response missing user.');
    }
    return AdminUser.fromJson(raw);
  }

  /// Promotes the player to admin role and records an audit log entry.
  Future<AdminUser> promoteUser(String userId) async {
    final response = await _api.authenticatedRequest(
      'POST',
      '/admin/users/$userId/promote',
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['user'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Promote user response missing user.');
    }
    return AdminUser.fromJson(raw);
  }

  /// Demotes the admin to player role and records an audit log entry.
  Future<AdminUser> demoteUser(String userId) async {
    final response = await _api.authenticatedRequest(
      'POST',
      '/admin/users/$userId/demote',
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['user'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Demote user response missing user.');
    }
    return AdminUser.fromJson(raw);
  }

  // ─── Tickets ─────────────────────────────────────────────────────────────

  Future<({List<AdminTicket> tickets, int total})> listTickets({
    int limit  = 20,
    int offset = 0,
    String? status,
  }) async {
    final query = StringBuffer('/admin/tickets?limit=$limit&offset=$offset');
    if (status != null) query.write('&status=$status');

    final response   = await _api.authenticatedRequest('GET', query.toString());
    final data       = response['data'] as Map<String, dynamic>?;
    final rawTickets = data?['tickets'];
    if (rawTickets is! List) {
      throw const FormatException('Tickets response missing tickets array.');
    }

    final pagination = data?['pagination'] as Map<String, dynamic>?;
    final total = (pagination?['total'] as num?)?.toInt() ?? 0;

    return (
      tickets: rawTickets.whereType<Map<String, dynamic>>().map(AdminTicket.fromJson).toList(),
      total:   total,
    );
  }

  Future<AdminTicket> updateTicketStatus(String ticketId, String status) async {
    final response = await _api.authenticatedRequest(
      'PATCH',
      '/admin/tickets/$ticketId/status',
      body: {'status': status},
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw  = data?['ticket'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Update ticket status response missing ticket.');
    }
    return AdminTicket.fromJson(raw);
  }

  // ─── Phase 10.2 — Audit log ───────────────────────────────────────────────

  Future<({List<AuditLogEntry> entries, int total})> getAuditLog({
    int limit  = 20,
    int offset = 0,
    String? adminId,
    String? targetUserId,
    String? action,
  }) async {
    final query = StringBuffer('/admin/audit-log?limit=$limit&offset=$offset');
    if (adminId      != null) query.write('&admin_id=$adminId');
    if (targetUserId != null) query.write('&target_user_id=$targetUserId');
    if (action       != null) query.write('&action=$action');

    final response  = await _api.authenticatedRequest('GET', query.toString());
    final data      = response['data'] as Map<String, dynamic>?;
    final rawItems  = data?['entries'];
    if (rawItems is! List) {
      throw const FormatException('Audit log response missing entries array.');
    }

    final pagination = data?['pagination'] as Map<String, dynamic>?;
    final total = (pagination?['total'] as num?)?.toInt() ?? 0;

    return (
      entries: rawItems.whereType<Map<String, dynamic>>().map(AuditLogEntry.fromJson).toList(),
      total:   total,
    );
  }
}
