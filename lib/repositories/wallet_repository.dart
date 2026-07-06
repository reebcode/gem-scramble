import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/result.dart';
import '../models/transaction.dart';
import '../models/user.dart';

/// Data access for the user profile (balances) and transaction history.
/// Also maintains a local cache of the last-known user so the UI can render
/// immediately while a refresh is in flight.
class WalletRepository {
  WalletRepository(this._api);

  static const _cachedUserKey = 'cached_user';

  final ApiClient _api;

  Future<Result<User>> fetchCurrentUser() async {
    final result = await _api.getJson('users/me');
    return switch (result) {
      Success(:final value) => _parseAndCacheUser(value),
      Failure(:final message) => Failure(message),
    };
  }

  Result<User> _parseAndCacheUser(Map<String, dynamic> json) {
    try {
      final user = User.fromJson(json);
      // Fire-and-forget cache write; a failed cache must not fail the fetch.
      _cacheUser(user);
      return Success(user);
    } catch (e) {
      return Failure('Unexpected user response: $e');
    }
  }

  Future<Result<List<Transaction>>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _api.getJson('wallet/transactions', queryParams: {
      'limit': '$limit',
      'offset': '$offset',
    });
    return switch (result) {
      Success(:final value) => _parseTransactions(value),
      Failure(:final message) => Failure(message),
    };
  }

  Result<List<Transaction>> _parseTransactions(Map<String, dynamic> json) {
    try {
      final list = (json['transactions'] as List? ?? const [])
          .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
          .toList();
      return Success(list);
    } catch (e) {
      return Failure('Unexpected transactions response: $e');
    }
  }

  Future<User?> loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserKey);
      if (raw == null) return null;
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
    } catch (_) {
      // Cache is best-effort.
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserKey);
    } catch (_) {}
  }
}
