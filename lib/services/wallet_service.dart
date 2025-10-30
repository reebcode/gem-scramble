import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import 'api_service.dart';

class WalletService {
  static WalletService? _instance;
  static WalletService get instance => _instance ??= WalletService._();

  WalletService._();

  final ApiService _apiService = ApiService.instance;
  final StreamController<User> _userController =
      StreamController<User>.broadcast();
  final StreamController<List<Transaction>> _transactionsController =
      StreamController<List<Transaction>>.broadcast();

  User? _currentUser;
  List<Transaction> _transactions = [];
  Timer? _balanceUpdateTimer;

  // Streams
  Stream<User> get userStream => _userController.stream;
  Stream<List<Transaction>> get transactionsStream =>
      _transactionsController.stream;

  // Getters
  User? get currentUser => _currentUser;
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  int get gemBalance => _currentUser?.gems ?? 0;
  int get bonusGemBalance => _currentUser?.bonusGems ?? 0;
  int get totalGemBalance => _currentUser?.totalGems ?? 0;

  // Initialize wallet service
  Future<void> initialize() async {
    debugPrint('WalletService: Initializing...');
    await _loadUserFromCache();
    await refreshUser();
    await refreshTransactions();
    _startBalanceUpdateTimer();
    debugPrint('WalletService: Initialization complete');
  }

  // Ensure wallet service is initialized (for screen navigation)
  Future<void> ensureInitialized() async {
    if (_currentUser == null) {
      debugPrint('WalletService: User data missing, reinitializing...');
      await initialize();
    }
  }

  // Load user from cache
  Future<void> _loadUserFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('cached_user');
      if (userJson != null) {
        final userData =
            Map<String, dynamic>.from(const JsonDecoder().convert(userJson));
        _currentUser = User.fromJson(userData);
        _userController.add(_currentUser!);
        debugPrint('WalletService: Loaded user from cache - gems: ${_currentUser!.gems}, bonus: ${_currentUser!.bonusGems}');
      } else {
        debugPrint('WalletService: No cached user data found');
      }
    } catch (e) {
      debugPrint('Error loading user from cache: $e');
      // Leave user null on failure; UI will reflect zero balances
    }
  }

  // Cache user data
  Future<void> _cacheUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'cached_user', const JsonEncoder().convert(user.toJson()));
    } catch (e) {
      debugPrint('Error caching user: $e');
    }
  }

  // Refresh user data from server
  Future<bool> refreshUser() async {
    try {
      debugPrint('WalletService: Refreshing user data...');
      final user = await _apiService.getCurrentUser();
      if (user != null) {
        debugPrint(
            'WalletService: Got user data - gems: ${user.gems}, bonus: ${user.bonusGems}');
        _currentUser = user;
        _userController.add(user);
        await _cacheUser(user);
        return true;
      } else {
        debugPrint('WalletService: No user data returned from API - keeping existing user data');
        // Don't clear the current user if API fails - keep existing data
        if (_currentUser != null) {
          _userController.add(_currentUser!);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing user: $e - keeping existing user data');
      // Don't clear the current user if API fails - keep existing data
      if (_currentUser != null) {
        _userController.add(_currentUser!);
      }
    }
    return false;
  }

  // Prompt username if backend indicates it's missing
  Future<void> ensureUsername(BuildContext? context) async {
    try {
      final user = await _apiService.getCurrentUser();
      if (user == null) return;
      // If backend added needsUsername flag, handle via transactions stream
    } catch (_) {}
  }

  // Refresh transactions from server
  Future<bool> refreshTransactions() async {
    try {
      final transactions = await _apiService.getTransactions();
      _transactions = transactions;
      _transactionsController.add(_transactions);
      return true;
    } catch (e) {
      debugPrint('Error refreshing transactions: $e');
    }
    return false;
  }

  // Update balance locally (for immediate UI feedback)
  void updateBalanceLocally({
    int? gemsDelta,
    int? bonusGemsDelta,
  }) {
    if (_currentUser == null) return;

    final newUser = _currentUser!.copyWith(
      gems: gemsDelta != null ? _currentUser!.gems + gemsDelta : null,
      bonusGems: bonusGemsDelta != null
          ? _currentUser!.bonusGems + bonusGemsDelta
          : null,
    );

    _currentUser = newUser;
    _userController.add(newUser);
  }

  // Add transaction locally (for immediate UI feedback)
  void addTransactionLocally(Transaction transaction) {
    _transactions.insert(0, transaction);
    _transactionsController.add(_transactions);
  }

  // Simulate balance change with animation
  Future<void> animateBalanceChange({
    required int amount,
    required Currency currency,
    required TransactionType type,
  }) async {
    // Add transaction immediately for UI feedback
    final transaction = Transaction(
      txId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      amount: amount,
      currency: currency,
      timestamp: DateTime.now(),
      status: 'completed',
    );

    addTransactionLocally(transaction);

    // Update balance
    switch (currency) {
      case Currency.gems:
        updateBalanceLocally(gemsDelta: amount);
        break;
      case Currency.bonusGems:
        updateBalanceLocally(bonusGemsDelta: amount);
        break;
    }

    // Refresh from server after a delay to ensure consistency
    Future.delayed(const Duration(seconds: 2), () {
      refreshUser();
      refreshTransactions();
    });
  }

  // Start periodic balance updates
  void _startBalanceUpdateTimer() {
    _balanceUpdateTimer?.cancel();
    _balanceUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      refreshUser();
    });
  }

  // Check if user has sufficient balance
  bool hasSufficientBalance(int amount, Currency currency) {
    switch (currency) {
      case Currency.gems:
        return gemBalance >= amount;
      case Currency.bonusGems:
        return bonusGemBalance >= amount;
    }
  }

  // Get formatted balance strings
  String get formattedGemBalance => '$gemBalance gems';
  String get formattedBonusGemBalance => '$bonusGemBalance bonus gems';
  String get formattedTotalGemBalance => '$totalGemBalance gems';

  // Dispose
  void dispose() {
    _balanceUpdateTimer?.cancel();
    _userController.close();
    _transactionsController.close();
  }
}
