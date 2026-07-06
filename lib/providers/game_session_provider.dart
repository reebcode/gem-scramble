import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../models/match.dart';
import '../repositories/match_repository.dart';

/// Outcome of attempting to add a word during a game.
enum AddWordOutcome { accepted, duplicate, rejected, error }

/// Presentation state for an active game session: the current match, the
/// countdown, found words, and submission. The game screen is a pure
/// renderer over this state.
class GameSessionProvider extends ChangeNotifier {
  GameSessionProvider(this._repository);

  final MatchRepository _repository;

  Match? _match;
  final List<String> _foundWords = [];
  String _currentWord = '';
  int _clientScore = 0;
  int _timeRemaining = 0;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  Timer? _ticker;

  Match? get match => _match;
  List<String> get foundWords => List.unmodifiable(_foundWords);
  String get currentWord => _currentWord;

  /// Client-side running score, mirroring the server formula (length^2 per
  /// word) for immediate feedback; the server score is authoritative.
  int get clientScore => _clientScore;
  int get timeRemaining => _timeRemaining;
  bool get isSubmitting => _isSubmitting;
  bool get hasSubmitted => _hasSubmitted;
  bool get isTimeExpired => _timeRemaining <= 0;

  /// Joins a lobby and seeds session state from the returned match.
  Future<Result<Match>> joinLobby(String lobbyId, {String? playerName}) async {
    final result =
        await _repository.joinLobby(lobbyId, playerName: playerName);
    if (result case Success(:final value)) {
      _startSession(value);
    }
    return result;
  }

  void _startSession(Match match) {
    _match = match;
    _foundWords
      ..clear()
      ..addAll(match.myWords);
    _clientScore = _foundWords.fold(0, (sum, w) => sum + w.length * w.length);
    _currentWord = '';
    _isSubmitting = false;
    _hasSubmitted = false;
    _timeRemaining = _computeRemainingSeconds(match);
    _startTicker();
    notifyListeners();
  }

  static int _computeRemainingSeconds(Match match) {
    final deadline = match.playerDeadlineAt;
    if (deadline != null) {
      final seconds =
          ((deadline.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch) /
                  1000)
              .floor();
      return seconds < 0 ? 0 : seconds;
    }
    return match.timer;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        notifyListeners();
      } else {
        _ticker?.cancel();
      }
    });
  }

  /// Updates the word currently being traced on the board.
  void setCurrentWord(String word) {
    if (_currentWord == word) return;
    _currentWord = word;
    notifyListeners();
  }

  /// Validates a traced word against the server (dictionary + board) and,
  /// when accepted, records it and auto-saves progress.
  Future<AddWordOutcome> tryAddWord(String word) async {
    final match = _match;
    if (match == null || _hasSubmitted) return AddWordOutcome.error;

    final normalized = word.toLowerCase();
    if (_foundWords.contains(normalized)) return AddWordOutcome.duplicate;

    final result = await _repository.validateWord(match.matchId, word);
    return result.when(
      success: (valid) {
        if (!valid) return AddWordOutcome.rejected;
        _foundWords.add(normalized);
        _clientScore += normalized.length * normalized.length;
        notifyListeners();
        _autoSave();
        return AddWordOutcome.accepted;
      },
      failure: (_) => AddWordOutcome.error,
    );
  }

  void _autoSave() {
    final match = _match;
    if (match == null) return;
    // Fire-and-forget: saved words are a resilience feature (restored on
    // reconnect and used for auto-submission at the deadline).
    _repository.saveWords(match.matchId, _foundWords).then((result) {
      if (result case Failure(:final message)) {
        debugPrint('Auto-save failed: $message');
      }
    });
  }

  /// Submits found words for final scoring, then refreshes the match so the
  /// UI can show the authoritative score breakdown.
  Future<Result<int>> submitWords() async {
    final match = _match;
    if (match == null) return const Failure('No active match');
    if (_hasSubmitted) return const Failure('Already submitted');

    _isSubmitting = true;
    notifyListeners();

    final result = await _repository.submitWords(match.matchId, _foundWords);
    if (result.isSuccess) {
      _hasSubmitted = true;
      _ticker?.cancel();
      // Best-effort refresh for the server-side score breakdown.
      final updated = await _repository.getMatch(match.matchId);
      if (updated case Success(:final value)) {
        _match = value;
      }
    }
    _isSubmitting = false;
    notifyListeners();
    return result;
  }

  /// Leaves the current (not yet submitted) match and clears the session.
  Future<Result<void>> leaveMatch() async {
    final result = await _repository.leaveMatch();
    if (result.isSuccess) reset();
    return result;
  }

  /// Clears all session state (e.g. when returning to the lobby).
  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _match = null;
    _foundWords.clear();
    _currentWord = '';
    _clientScore = 0;
    _timeRemaining = 0;
    _isSubmitting = false;
    _hasSubmitted = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
