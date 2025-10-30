import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import 'api_service.dart';
import 'wallet_service.dart';

class MatchmakingService {
  static MatchmakingService? _instance;
  static MatchmakingService get instance =>
      _instance ??= MatchmakingService._();

  MatchmakingService._();

  final ApiService _apiService = ApiService.instance;

  final StreamController<Match> _matchController =
      StreamController<Match>.broadcast();
  final StreamController<Match> _matchEndController =
      StreamController<Match>.broadcast();

  Match? _currentMatch;
  Timer? _gameTimer;
  Timer? _pollingTimer;
  int _timeRemaining = 0;
  bool _isPolling = false;

  // Streams
  Stream<Match> get matchStream => _matchController.stream;
  Stream<Match> get matchEndStream => _matchEndController.stream;

  // Getters
  Match? get currentMatch => _currentMatch;
  int get timeRemaining => _timeRemaining;
  bool get isInMatch => _currentMatch != null && !_currentMatch!.completed;

  // Initialize matchmaking service
  Future<void> initialize() async {
    // No WebSocket connection needed - we'll use polling
    debugPrint('MatchmakingService initialized with HTTPS-only mode');
  }

  // Join a lobby
  Future<Match?> joinLobby(String lobbyId) async {
    try {
      final match = await _apiService.joinLobby(lobbyId);
      if (match != null) {
        _currentMatch = match;
        // Seed timer from per-player deadline when available; fallback to server timer
        if (match.playerDeadlineAt != null) {
          final endMs = match.playerDeadlineAt!.millisecondsSinceEpoch;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          _timeRemaining = ((endMs - nowMs) / 1000).floor();
          if (_timeRemaining < 0) _timeRemaining = 0;
        } else {
          _timeRemaining = match.timer;
        }

        // Start the game timer
        _startGameTimer();

        // Start polling for match updates (only if match is waiting for more players)
        if (match.startedAt == null) {
          _startPolling();
        }

        _matchController.add(match);

        // Refresh wallet balances/transactions after entry fee debit
        try {
          await WalletService.instance.refreshUser();
          await WalletService.instance.refreshTransactions();
        } catch (_) {}
      }
      return match;
    } catch (e) {
      debugPrint('Error joining lobby: $e');
      return null;
    }
  }

  // Save words (auto-save without submitting)
  Future<bool> saveWords(List<String> words) async {
    if (_currentMatch == null) return false;

    try {
      final success =
          await _apiService.saveWords(_currentMatch!.matchId, words);
      if (success) {
        debugPrint('Words auto-saved: ${words.length} words');
      }
      return success;
    } catch (e) {
      debugPrint('Error saving words: $e');
      return false;
    }
  }

  // Submit words
  Future<bool> submitWords(List<String> words) async {
    if (_currentMatch == null) return false;

    try {
      // First save the words to ensure they're preserved
      await saveWords(words);

      final success =
          await _apiService.submitWords(_currentMatch!.matchId, words);
      if (success) {
        // Stop polling since we've submitted
        _stopPolling();

        // Get updated match data
        final updatedMatch =
            await _apiService.getMatchResult(_currentMatch!.matchId);
        if (updatedMatch != null) {
          _currentMatch = updatedMatch;
          _matchController.add(updatedMatch);

          // If match is completed, emit match end event
          if (updatedMatch.completed) {
            _matchEndController.add(updatedMatch);
            _stopGameTimer();
          }
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error submitting words: $e');
      return false;
    }
  }

  // Validate a single word against the current match (server-side)
  Future<bool> validateWord(String word) async {
    if (_currentMatch == null) return false;
    try {
      return await _apiService.validateWord(_currentMatch!.matchId, word);
    } catch (e) {
      debugPrint('Error validating word: $e');
      return false;
    }
  }

  // Start game timer (5 minutes countdown)
  void _startGameTimer() {
    _stopGameTimer();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_timeRemaining > 0) {
        _timeRemaining--;
      } else {
        _stopGameTimer();
        // Auto-submit words when time runs out
        await _autoSubmitWords();
      }
    });
  }

  // Stop game timer
  void _stopGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  // Auto-submit words when time runs out
  Future<void> _autoSubmitWords() async {
    if (_currentMatch != null &&
        !_currentMatch!.completed &&
        _currentMatch!.myWords.isNotEmpty) {
      debugPrint('Auto-submitting words due to timer expiration');
      await submitWords(_currentMatch!.myWords);
    }
  }

  // Start polling for match updates (only for waiting matches)
  void _startPolling() {
    if (_isPolling || _currentMatch == null) return;

    _isPolling = true;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkMatchUpdates();
    });
  }

  // Stop polling
  void _stopPolling() {
    _isPolling = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // Check for match updates
  Future<void> _checkMatchUpdates() async {
    if (_currentMatch == null || _currentMatch!.completed) {
      _stopPolling();
      return;
    }

    try {
      final updatedMatch =
          await _apiService.getMatchResult(_currentMatch!.matchId);
      if (updatedMatch != null) {
        // Check if match status changed
        if (updatedMatch.completed != _currentMatch!.completed) {
          _currentMatch = updatedMatch;
          _matchController.add(updatedMatch);

          if (updatedMatch.completed) {
            _matchEndController.add(updatedMatch);
            _stopGameTimer();
            _stopPolling();
          }
        }

        // Check if match started (got enough players)
        if (updatedMatch.startedAt != null &&
            _currentMatch!.startedAt == null) {
          _currentMatch = updatedMatch;
          _matchController.add(updatedMatch);
          _stopPolling(); // No need to poll once match has started
        }
      }
    } catch (e) {
      debugPrint('Error checking match updates: $e');
    }
  }

  // Get match details (for results screen)
  Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    try {
      return await _apiService.getMatchDetails(matchId);
    } catch (e) {
      debugPrint('Error getting match details: $e');
      return null;
    }
  }

  // Leave current match
  Future<bool> leaveMatch() async {
    if (_currentMatch == null) return false;

    try {
      final success = await _apiService.leaveMatch(_currentMatch!.matchId);
      if (success) {
        _stopGameTimer();
        _stopPolling();
        _currentMatch = null;
        _timeRemaining = 0;
      }
      return success;
    } catch (e) {
      debugPrint('Error leaving match: $e');
      return false;
    }
  }

  // Cleanup
  void dispose() {
    _stopGameTimer();
    _stopPolling();
    _matchController.close();
    _matchEndController.close();
  }
}
