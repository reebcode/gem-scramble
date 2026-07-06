import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import '../models/user.dart';
import '../repositories/wallet_repository.dart';

/// Presentation state for the user's wallet: profile/balances and
/// transaction history, with explicit loading and error states.
class WalletProvider extends ChangeNotifier {
  WalletProvider(this._repository);

  final WalletRepository _repository;

  User? _user;
  List<Transaction> _transactions = const [];
  bool _isLoadingUser = false;
  bool _isLoadingTransactions = false;
  String? _userError;
  String? _transactionsError;
  Timer? _refreshTimer;
  bool _initialized = false;

  User? get user => _user;
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoadingUser => _isLoadingUser;
  bool get isLoadingTransactions => _isLoadingTransactions;
  String? get userError => _userError;
  String? get transactionsError => _transactionsError;

  int get gemBalance => _user?.gems ?? 0;
  int get bonusGemBalance => _user?.bonusGems ?? 0;
  int get totalGemBalance => _user?.totalGems ?? 0;

  /// Loads the cached user for instant UI, then refreshes from the server
  /// and starts a periodic background refresh.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final cached = await _repository.loadCachedUser();
    if (cached != null) {
      _user = cached;
      notifyListeners();
    }
    await Future.wait([refreshUser(), refreshTransactions()]);

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshUser(),
    );
  }

  Future<void> refreshUser() async {
    _isLoadingUser = true;
    notifyListeners();

    final result = await _repository.fetchCurrentUser();
    result.when(
      success: (user) {
        _user = user;
        _userError = null;
      },
      failure: (message) {
        // Keep last-known data; only surface the error.
        _userError = message;
      },
    );
    _isLoadingUser = false;
    notifyListeners();
  }

  Future<void> refreshTransactions() async {
    _isLoadingTransactions = true;
    notifyListeners();

    final result = await _repository.fetchTransactions();
    result.when(
      success: (list) {
        _transactions = list;
        _transactionsError = null;
      },
      failure: (message) {
        _transactionsError = message;
      },
    );
    _isLoadingTransactions = false;
    notifyListeners();
  }

  /// Clears all wallet state (used on logout).
  Future<void> clear() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _initialized = false;
    _user = null;
    _transactions = const [];
    _userError = null;
    _transactionsError = null;
    await _repository.clearCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
