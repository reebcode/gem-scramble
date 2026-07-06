import 'package:flutter/foundation.dart';

import '../models/match.dart';
import '../repositories/match_repository.dart';

/// Presentation state for the user's match history (results tab).
class MatchHistoryProvider extends ChangeNotifier {
  MatchHistoryProvider(this._repository);

  final MatchRepository _repository;

  List<Match> _matches = const [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  List<Match> get matches => List.unmodifiable(_matches);
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  Future<void> loadMatches({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _repository.getMyMatches();
    result.when(
      success: (list) {
        _matches = list;
        _error = null;
      },
      failure: (message) {
        // On silent background refreshes keep showing stale data.
        if (!silent) _error = message;
      },
    );
    _isLoading = false;
    _hasLoadedOnce = true;
    notifyListeners();
  }
}
