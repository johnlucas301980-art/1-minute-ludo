import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/admin_stats.dart';
import '../models/admin_ticket.dart';
import '../models/admin_user.dart';

/// Provides access to the admin backend endpoints.
///
/// All methods require an authenticated admin session. A [ApiException] with
/// status 403 is thrown when the authenticated user is not an admin.
class AdminService {
  AdminService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── Stats ────────────────────────────────────────────────────────────────

  /// Returns dashboard statistics.
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
  Future<({List<AdminUser> users, int total})> listUsers({
    int limit  = 20,
    int offset = 0,
    String? status,
    String? role,
  }) async {
    final query = StringBuffer('/admin/users?limit=$limit&offset=$offset');
    if (status != null) query.write('&status=$status');
    if (role   != null) query.write('&role=$role');

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
  ///
  /// Returns `null` if the user does not exist (404).
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

  /// Updates a user's status. [status] must be one of: active, suspended, banned.
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

  /// Updates a user's role. [role] must be one of: player, admin.
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

  // ─── Tickets ─────────────────────────────────────────────────────────────

  /// Returns a paginated list of all support tickets across all users.
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

  /// Updates a support ticket's status.
  /// [status] must be one of: open, in_progress, resolved, closed.
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
}
