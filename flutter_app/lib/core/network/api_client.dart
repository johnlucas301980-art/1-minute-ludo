import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// HTTP client wrapper for 1 Minute Ludo REST API calls.
///
/// All requests go through this class so auth headers, base URL,
/// and error handling are applied consistently.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();

  /// Authorization token, set after login.
  String? _authToken;

  void setAuthToken(String token) => _authToken = token;
  void clearAuthToken() => _authToken = null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<http.Response> get(String path) =>
      _client.get(_uri(path), headers: _headers).timeout(AppConfig.httpTimeout);

  Future<http.Response> post(String path, Map<String, dynamic> body) =>
      _client
          .post(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(AppConfig.httpTimeout);

  Future<http.Response> put(String path, Map<String, dynamic> body) =>
      _client
          .put(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(AppConfig.httpTimeout);

  Future<http.Response> delete(String path) =>
      _client
          .delete(_uri(path), headers: _headers)
          .timeout(AppConfig.httpTimeout);
}
