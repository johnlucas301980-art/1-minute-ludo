import '../../../core/network/api_client.dart';
import '../models/country.dart';

/// Fetches country data from the backend.
///
/// Call [detect] once at app start (or auth-screen mount) to get:
/// - The user's auto-detected country (may be null for private IPs / failures).
/// - The full list of countries for the picker.
class CountryService {
  CountryService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // Cache the full list after the first fetch so the picker never re-requests.
  List<Country>? _cachedList;
  Country?       _cachedDetected;
  bool           _fetched = false;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Returns the auto-detected country for this device (may be null).
  ///
  /// The first call hits the backend; subsequent calls return the cached value.
  Future<Country?> getDetected() async {
    if (!_fetched) await _fetchAndCache();
    return _cachedDetected;
  }

  /// Returns the full list of countries supported by this app.
  ///
  /// The first call hits the backend; subsequent calls return the cached value.
  Future<List<Country>> getAll() async {
    if (!_fetched) await _fetchAndCache();
    return _cachedList ?? [];
  }

  // ─── Internals ──────────────────────────────────────────────────────────────

  Future<void> _fetchAndCache() async {
    try {
      final json = await _api.publicRequest('GET', '/geo/detect');
      final data = json['data'] as Map<String, dynamic>;

      final rawDetected = data['detected'];
      _cachedDetected = rawDetected is Map<String, dynamic>
          ? Country.fromJson(rawDetected)
          : null;

      final rawList = data['countries'];
      if (rawList is List) {
        _cachedList = rawList
            .whereType<Map<String, dynamic>>()
            .map(Country.fromJson)
            .toList();
      } else {
        _cachedList = [];
      }
    } catch (_) {
      // Network failure — return empty; the picker will still work with an
      // empty list and the user can type manually.
      _cachedDetected = null;
      _cachedList     = [];
    } finally {
      _fetched = true;
    }
  }
}
