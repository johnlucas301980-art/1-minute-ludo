import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_country.dart';

/// Exception thrown when an admin country API call fails.
class AdminCountryServiceException implements Exception {
  final String message;
  final int? statusCode;

  const AdminCountryServiceException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'AdminCountryServiceException($statusCode): $message'
      : 'AdminCountryServiceException: $message';
}

/// Service for admin country endpoints.
///
/// Usage:
/// ```dart
/// final service = AdminCountryService(
///   baseUrl: AppConfig.apiBaseUrl,
///   authToken: token,
/// );
///
/// final countries = await service.getCountries();
/// final updated  = await service.updateCountry('NG', {'isActive': false});
/// ```
class AdminCountryService {
  final String baseUrl;
  final String authToken;

  const AdminCountryService({
    required this.baseUrl,
    required this.authToken,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

  /// GET /api/admin/countries
  ///
  /// Returns all countries from the admin API.
  /// Throws [AdminCountryServiceException] on non-200 responses or network errors.
  Future<List<AdminCountry>> getCountries() async {
    final uri = Uri.parse('$baseUrl/api/admin/countries');

    final http.Response response;
    try {
      response = await http.get(uri, headers: _headers);
    } catch (e) {
      throw AdminCountryServiceException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw AdminCountryServiceException(
        'Failed to fetch countries',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AdminCountryServiceException('Unexpected response shape');
    }

    final dynamic data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw AdminCountryServiceException('Missing data field in response');
    }

    final dynamic countries = data['countries'];
    if (countries is! List) {
      throw AdminCountryServiceException('Missing countries list in response');
    }

    return countries
        .map((e) => AdminCountry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /api/admin/countries/:iso2
  ///
  /// Sends [updates] as a JSON body and returns the updated [AdminCountry].
  /// Throws [AdminCountryServiceException] on non-200 responses or network errors.
  Future<AdminCountry> updateCountry(
    String iso2,
    Map<String, dynamic> updates,
  ) async {
    final uri = Uri.parse('$baseUrl/api/admin/countries/$iso2');

    final http.Response response;
    try {
      response = await http.put(
        uri,
        headers: _headers,
        body: jsonEncode(updates),
      );
    } catch (e) {
      throw AdminCountryServiceException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw AdminCountryServiceException(
        'Failed to update country $iso2',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AdminCountryServiceException('Unexpected response shape');
    }

    return AdminCountry.fromJson(decoded);
  }
}
