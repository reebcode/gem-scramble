import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import 'api_service.dart';

class GemService {
  static GemService? _instance;
  static GemService get instance => _instance ??= GemService._();

  GemService._();


  /// Award bonus gems to a user (for promotions, achievements, etc.)
  Future<bool> awardBonusGems({
    required int amount,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/gems/award'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('GemService: Successfully awarded $amount bonus gems for $reason');
        return true;
      } else {
        debugPrint('GemService: Failed to award gems: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('GemService: Error awarding gems: $e');
      return false;
    }
  }

  /// Get gem transaction history
  Future<List<Transaction>> getGemTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/gems/transactions?limit=$limit&offset=$offset'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['transactions'] as List)
            .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('GemService: Failed to get transactions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('GemService: Error getting transactions: $e');
      return [];
    }
  }

  /// Check if user has enough gems for an action
  bool hasEnoughGems(int requiredGems) {
    // This would typically check against the current user's gem balance
    // For now, return true as a placeholder
    return true;
  }

  /// Get gem balance summary
  Map<String, int> getGemBalanceSummary() {
    // This would typically return the current user's gem balances
    // For now, return placeholder values
    return {
      'gems': 100,
      'bonusGems': 0,
      'totalGems': 100,
    };
  }
}
