import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/match.dart';
import '../models/lobby.dart';
import '../models/transaction.dart';
import 'config_service.dart';

class ApiService {
  // Choose base URL at runtime:
  // - Web on localhost → local API
  // - Web on hosted → Railway API
  // - Non-web debug → local API
  // - Non-web release → Railway API
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:8080';
      }
      return 'https://your-api-domain.com';
    }
    return kDebugMode
        ? 'http://localhost:8080'
        : 'https://your-api-domain.com';
  }

  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();

  ApiService._();

  final http.Client _client = http.Client();
  String? _devUserId;
  bool _isInitialized = false;

  // Initialize and load dev user ID if in dev mode
  Future<void> initialize() async {
    if (_isInitialized) return;

    final isDevAuth = await ConfigService.instance.isDevAuth();
    if (isDevAuth) {
      final prefs = await SharedPreferences.getInstance();
      _devUserId = prefs.getString('user_id');
      debugPrint('ApiService initialized in dev mode with userId: $_devUserId');

      // If no user ID found, we need to login first
      if (_devUserId == null) {
        debugPrint('No dev user ID found in preferences');
      }
    } else {
      debugPrint('ApiService initialized in Firebase mode.');
    }
    _isInitialized = true;
  }

  // Check if a user is logged in for dev mode
  bool isDevUserLoggedIn() {
    return _devUserId != null;
  }

  // Ensure API service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Dev mode login
  Future<User?> loginOrRegisterWithUsername(String username) async {
    final isDevAuth = await ConfigService.instance.isDevAuth();
    if (!isDevAuth) {
      debugPrint("Attempted to call dev login in production mode.");
      return null;
    }
    try {
      final resp = await _client.post(
        Uri.parse('$baseUrl/users/login-or-register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = User.fromJson(data);
        _devUserId = user.id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _devUserId!);
        return user;
      }
    } catch (e) {
      debugPrint('loginOrRegisterWithUsername error: $e');
    }
    return null;
  }

  Future<void> devLogout() async {
    final isDevAuth = await ConfigService.instance.isDevAuth();
    if (isDevAuth) {
      _devUserId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    }
  }

  // Get headers, conditionally adding Firebase token
  Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final isDevAuth = await ConfigService.instance.isDevAuth();
    if (!isDevAuth) {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found for Firebase mode.');
      }
      final token = await user.getIdToken();
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Centralized request execution
  Future<http.Response> _execute(
      Future<http.Response> Function(Uri, {Map<String, String>? headers})
          request,
      String path,
      {Map<String, String>? queryParams}) async {
    var url = '$baseUrl/$path';
    if (queryParams != null) {
      url += '?${Uri(queryParameters: queryParams).query}';
    }
    return await request(Uri.parse(url), headers: await _getHeaders());
  }

  // User operations
  Future<User?> getCurrentUser() async {
    try {
      await _ensureInitialized();
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth && _devUserId == null) {
        debugPrint('getCurrentUser: No dev user ID available');
        return null;
      }
      final queryParams = isDevAuth ? {'userId': _devUserId!} : null;
      final response =
          await _execute(_client.get, 'users/me', queryParams: queryParams);

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
            'Failed to get user, status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      debugPrint('getCurrentUser error: $e');
    }
    return null;
  }

  // Set username for current user
  Future<bool> setUsername(String username) async {
    try {
      final body = <String, dynamic>{'username': username};
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth) {
        body['userId'] = _devUserId;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/users/username'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
            'Failed to set username, status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      debugPrint('setUsername error: $e');
    }
    return false;
  }

  // Lobby operations
  Future<List<Lobby>> getLobbies() async {
    try {
      final response = await _execute(_client.get, 'lobbies');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['lobbies'] as List)
            .map((j) => Lobby.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('getLobbies error: $e');
    }
    return [];
  }

  Future<Match?> joinLobby(String lobbyId) async {
    try {
      final body = <String, dynamic>{'lobbyType': lobbyId};
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth) {
        body['userId'] = _devUserId;
        // Get username from database
        final user = await getCurrentUser();
        body['playerName'] = user?.username ?? 'DemoPlayer';
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/matches/join'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return Match.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('currentMatch')) {
          return Match.fromJson(data['currentMatch']);
        }
      } else {
        debugPrint(
            'joinLobby failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('joinLobby error: $e');
    }
    return null;
  }

  // Match operations
  Future<List<Match>> getMyMatches() async {
    try {
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth && _devUserId == null) {
        debugPrint('getMyMatches: No dev user ID available');
        return [];
      }
      final queryParams = isDevAuth ? {'userId': _devUserId!} : null;
      final response =
          await _execute(_client.get, 'matches', queryParams: queryParams);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['matches'] as List)
            .map((j) => Match.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('getMyMatches error: $e');
    }
    return [];
  }

  Future<List<Transaction>> getTransactions(
      {int limit = 50, int offset = 0}) async {
    try {
      await _ensureInitialized();
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth) {
        if (_devUserId == null) {
          debugPrint('getTransactions: No dev user ID available');
          return [];
        }
        queryParams['userId'] = _devUserId!;
      }
      final response = await _execute(_client.get, 'wallet/transactions',
          queryParams: queryParams);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['transactions'] as List)
            .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('getTransactions error: $e');
    }
    return [];
  }

  // Save words for a match (without submitting)
  Future<bool> saveWords(String matchId, List<String> words) async {
    try {
      final body = <String, dynamic>{'words': words};
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth) {
        body['userId'] = _devUserId;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/matches/$matchId/save-words'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('saveWords failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('saveWords error: $e');
    }
    return false;
  }

  // Submit words for a match
  Future<bool> submitWords(String matchId, List<String> words) async {
    try {
      final body = <String, dynamic>{'words': words};
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth) {
        body['userId'] = _devUserId;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/matches/$matchId/words'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['ok'] == true;
      } else {
        debugPrint(
            'submitWords failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('submitWords error: $e');
    }
    return false;
  }

  // Validate a single word for a match (dictionary + board)
  Future<bool> validateWord(String matchId, String word) async {
    try {
      final body = <String, dynamic>{'word': word};
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth) {
        body['userId'] = _devUserId;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/matches/$matchId/validate'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['valid'] == true;
      } else {
        debugPrint(
            'validateWord failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('validateWord error: $e');
    }
    return false;
  }

  // Get match result/details
  Future<Match?> getMatchResult(String matchId) async {
    try {
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth && _devUserId == null) {
        debugPrint('getMatchResult: No dev user ID available');
        return null;
      }
      final queryParams = isDevAuth ? {'userId': _devUserId!} : null;
      final response = await _execute(_client.get, 'matches/$matchId',
          queryParams: queryParams);

      if (response.statusCode == 200) {
        return Match.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
            'getMatchResult failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('getMatchResult error: $e');
    }
    return null;
  }

  // Get match details (returns raw JSON)
  Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    try {
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth && _devUserId == null) {
        debugPrint('getMatchDetails: No dev user ID available');
        return null;
      }
      final queryParams = isDevAuth ? {'userId': _devUserId!} : null;
      final response = await _execute(_client.get, 'matches/$matchId/details',
          queryParams: queryParams);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint(
            'getMatchDetails failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('getMatchDetails error: $e');
    }
    return null;
  }

  // Leave a match
  Future<bool> leaveMatch(String matchId) async {
    try {
      final body = <String, dynamic>{};
      final isDevAuth = await ConfigService.instance.isDevAuth();
      if (isDevAuth) {
        body['userId'] = _devUserId;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/matches/$matchId/leave'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['ok'] == true;
      } else {
        debugPrint(
            'leaveMatch failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('leaveMatch error: $e');
    }
    return false;
  }

  void dispose() {
    _client.close();
  }
}
