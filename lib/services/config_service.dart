import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConfigService {
  static ConfigService? _instance;
  static ConfigService get instance => _instance ??= ConfigService._();

  ConfigService._();

  static const String _baseUrl = kDebugMode
      ? 'http://localhost:8080'
      : 'https://your-api-domain.com';
  String? _authMode;
  bool? _isDevAuth;

  // Get auth mode from backend
  Future<String> getAuthMode() async {
    if (_authMode != null) return _authMode!;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/config'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _authMode = data['authMode'] as String? ?? 'dev';
        _isDevAuth = _authMode == 'dev';
        debugPrint('ConfigService: Auth mode from backend: $_authMode');
        return _authMode!;
      } else {
        debugPrint(
            'ConfigService: Failed to get config, status: ${response.statusCode}');
        _authMode = 'dev'; // Default fallback
        _isDevAuth = true;
        return _authMode!;
      }
    } catch (e) {
      debugPrint('ConfigService: Error getting config: $e');
      _authMode = 'dev'; // Default fallback
      _isDevAuth = true;
      return _authMode!;
    }
  }

  // Check if we're in dev auth mode
  Future<bool> isDevAuth() async {
    if (_isDevAuth != null) return _isDevAuth!;
    await getAuthMode();
    return _isDevAuth!;
  }

  // Check if we're in Firebase auth mode
  Future<bool> isFirebaseAuth() async {
    return !(await isDevAuth());
  }
}
