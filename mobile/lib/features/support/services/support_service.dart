import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/faq_item.dart';
import '../models/support_ticket.dart';

/// Provides access to the Help & Support backend endpoints.
///
/// All methods require an authenticated session. [SessionExpiredException] is
/// propagated unchanged to the caller when the token cannot be refreshed.
class SupportService {
  SupportService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ─── FAQs ────────────────────────────────────────────────────────────────────

  /// Returns the static FAQ list from the backend.
  ///
  /// Throws [ApiException] on a non-2xx response, or [SessionExpiredException]
  /// when the session cannot be recovered.
  Future<List<FaqItem>> getFaqs() async {
    final response = await _api.authenticatedRequest('GET', '/support/faqs');
    final data = response['data'] as Map<String, dynamic>?;
    final rawFaqs = data?['faqs'];
    if (rawFaqs is! List) {
      throw const FormatException('FAQ response missing faqs array.');
    }

    return rawFaqs
        .whereType<Map<String, dynamic>>()
        .map(FaqItem.fromJson)
        .toList();
  }

  // ─── Tickets ─────────────────────────────────────────────────────────────────

  /// Submits a new support ticket.
  ///
  /// [subject] must be 3–255 characters; [message] must be 10–5000 characters.
  /// The backend enforces these limits and returns a 400 [ApiException] if they
  /// are violated.
  Future<SupportTicket> submitTicket({
    required String subject,
    required String message,
  }) async {
    final response = await _api.authenticatedRequest(
      'POST',
      '/support/tickets',
      body: {'subject': subject, 'message': message},
    );
    final data = response['data'] as Map<String, dynamic>?;
    final raw = data?['ticket'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Submit ticket response missing ticket.');
    }
    return SupportTicket.fromJson(raw);
  }

  /// Returns a paginated list of the authenticated player's support tickets,
  /// newest first.
  Future<List<SupportTicket>> getTickets({int limit = 20, int offset = 0}) async {
    final response = await _api.authenticatedRequest(
      'GET',
      '/support/tickets?limit=$limit&offset=$offset',
    );
    final data = response['data'] as Map<String, dynamic>?;
    final rawTickets = data?['tickets'];
    if (rawTickets is! List) {
      throw const FormatException('Tickets response missing tickets array.');
    }

    return rawTickets
        .whereType<Map<String, dynamic>>()
        .map(SupportTicket.fromJson)
        .toList();
  }

  /// Returns a single ticket by its ID.
  ///
  /// Returns `null` if the ticket does not exist or does not belong to the
  /// authenticated player (the backend returns 404 in both cases).
  Future<SupportTicket?> getTicketById(String ticketId) async {
    try {
      final response = await _api.authenticatedRequest(
        'GET',
        '/support/tickets/$ticketId',
      );
      final data = response['data'] as Map<String, dynamic>?;
      final raw = data?['ticket'];
      if (raw is! Map<String, dynamic>) return null;
      return SupportTicket.fromJson(raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
