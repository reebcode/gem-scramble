import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'result.dart';

/// How the backend expects requests to be authenticated.
enum AuthMode { dev, firebase }

/// Centralized HTTP client for the Gem Scramble API.
///
/// This is the only place in the app that:
///  - knows the base URL,
///  - resolves the auth mode (`/config`),
///  - attaches credentials (Firebase ID token, or `userId` in dev mode).
///
/// Repositories build on top of [getJson]/[postJson] and never touch
/// `package:http` directly.
class ApiClient {
  ApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  AuthMode? _authMode;

  /// Dev-mode user id, set by the auth repository after login/restore.
  String? devUserId;

  String get baseUrl => AppConfig.apiBaseUrl;

  /// Resolves the auth mode from the backend once and caches it.
  Future<AuthMode> getAuthMode() async {
    final cached = _authMode;
    if (cached != null) return cached;
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/config'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _authMode =
            data['authMode'] == 'firebase' ? AuthMode.firebase : AuthMode.dev;
        return _authMode!;
      }
    } catch (_) {
      // Fall through to the dev default below.
    }
    _authMode = AuthMode.dev;
    return _authMode!;
  }

  Future<bool> isDevAuth() async => (await getAuthMode()) == AuthMode.dev;

  Future<Map<String, String>> _headers() async {
    final headers = {'Content-Type': 'application/json'};
    if (await getAuthMode() == AuthMode.firebase) {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const ApiException('Not signed in');
      }
      final token = await user.getIdToken();
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// In dev mode the backend identifies the caller via an explicit userId;
  /// in Firebase mode identity comes from the verified token instead.
  Future<Map<String, String>> _withIdentity(Map<String, String>? params) async {
    final result = <String, String>{...?params};
    if (await isDevAuth()) {
      final id = devUserId;
      if (id != null) result['userId'] = id;
    }
    return result;
  }

  Future<Result<Map<String, dynamic>>> getJson(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final params = await _withIdentity(queryParams);
      final uri = Uri.parse('$baseUrl/$path')
          .replace(queryParameters: params.isEmpty ? null : params);
      final resp = await _http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _decode(resp);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Network error: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final payload = <String, dynamic>{...?body};
      if (authenticated && await isDevAuth()) {
        final id = devUserId;
        if (id != null) payload['userId'] ??= id;
      }
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/$path'),
            headers: authenticated
                ? await _headers()
                : {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      return _decode(resp);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Network error: $e');
    }
  }

  Result<Map<String, dynamic>> _decode(http.Response resp) {
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return Success(json ?? const {});
    }
    final message = json?['error']?.toString() ??
        json?['message']?.toString() ??
        'Request failed (${resp.statusCode})';
    return Failure(message);
  }

  void dispose() => _http.close();
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
