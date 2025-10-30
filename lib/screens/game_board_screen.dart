import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flame/game.dart';
import '../models/match.dart';
import '../game/scramble_game.dart';
// Removed client-side dictionary; rely on server validation at submission
import '../services/matchmaking_service.dart';

class GameBoardScreen extends StatefulWidget {
  final Match match;

  const GameBoardScreen({
    super.key,
    required this.match,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final List<String> _foundWords = [];
  int _currentScore = 0;
  String _currentWord = '';
  bool _isSubmitting = false;
  ScrambleGame? _game;

  Timer? _resultPoller;
  int _timeRemaining = 0;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    // No client dictionary to initialize
    if (widget.match.playerDeadlineAt != null) {
      final endMs = widget.match.playerDeadlineAt!.millisecondsSinceEpoch;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _timeRemaining = ((endMs - nowMs) / 1000).floor();
      if (_timeRemaining < 0) _timeRemaining = 0;
    } else {
      _timeRemaining = widget.match.timer;
    }
    _startUiTimer();
    _loadSavedWords();
  }

  // Load any previously saved words when reconnecting
  void _loadSavedWords() {
    if (widget.match.myWords.isNotEmpty) {
      setState(() {
        _foundWords.addAll(widget.match.myWords);
        // Recalculate score based on saved words
        _currentScore = _foundWords.fold(
            0, (sum, word) => sum + (word.length * word.length));
      });
      debugPrint('Loaded ${widget.match.myWords.length} saved words');
    }
  }

  void _safeSetCurrentWord(String word) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentWord = word;
        });
      });
    } else {
      setState(() {
        _currentWord = word;
      });
    }
  }

  void _safeAddWordFromGame(String word, int score, Rect tileRect) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addWord(word, score, tileRect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          // Timer and Score
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(77),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withAlpha(128),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${_timeRemaining}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Score: $_currentScore',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Game Board (Flame)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
              ),
              child: GameWidget(
                game: _game ??= ScrambleGame(
                    board: widget.match.board,
                    onCurrentWordChanged: _safeSetCurrentWord,
                    onWordCompleted: _safeAddWordFromGame),
                backgroundBuilder: (context) => Container(
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),

          // Current Word
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Current Word: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    _currentWord.isEmpty
                        ? 'Tap letters to form words'
                        : _currentWord,
                    style: TextStyle(
                      fontSize: 16,
                      color: _currentWord.isEmpty
                          ? Colors.grey
                          : const Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Found Words
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Found Words (${_foundWords.length})',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_foundWords.isNotEmpty)
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitWords,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: const Color(0xFFFFD700),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFFD700)),
                                    ),
                                  )
                                : const Text('Submit'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _foundWords.isEmpty
                        ? const Center(
                            child: Text(
                              'No words found yet.\nTap letters to form words!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _foundWords.length,
                            itemBuilder: (context, index) {
                              final word = _foundWords[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(51),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.green.withAlpha(128)),
                                ),
                                child: Text(
                                  word.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _resultPoller?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _addWord(String word, int score, Rect startRect) async {
    final normalized = word.toLowerCase();
    if (_foundWords.contains(normalized)) return;

    // Validate with server before accepting
    final isValid = await MatchmakingService.instance.validateWord(word);
    if (!mounted) return;

    if (isValid) {
      setState(() {
        _foundWords.add(normalized);
        _currentScore += score;
      });

      // Auto-save words when a new valid word is found
      _autoSaveWords();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found: ${word.toUpperCase()} (+$score points)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      // Visual celebration after successful validation
      _game?.triggerConfettiExplosion(startRect.center);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${word.toUpperCase()} is not valid'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // Auto-save words to prevent data loss
  void _autoSaveWords() {
    MatchmakingService.instance.saveWords(_foundWords).then((success) {
      if (success) {
        debugPrint('Words auto-saved: ${_foundWords.length} words');
      } else {
        debugPrint('Failed to auto-save words');
      }
    }).catchError((error) {
      debugPrint('Error auto-saving words: $error');
    });
  }

  Future<void> _submitWords({bool auto = false}) async {
    // Confirm submission if not auto-submitting
    if (!auto) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit Words?'),
          content: const Text(
              'Are you sure you want to submit? You won\'t be able to add more words.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isSubmitting = true;
    });

    bool ok = false;
    try {
      ok = await MatchmakingService.instance.submitWords(_foundWords);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (!mounted) return;

    // Get server-updated score if available
    final updated = MatchmakingService.instance.currentMatch;
    final serverScore = updated?.myScore ?? _currentScore;
    final wordScore = updated?.myWordScore;
    final timeBonus = updated?.myTimeBonus;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? 'Submitted!' : 'Submission Failed'),
        content: ok
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submitted: ${_foundWords.length} words'),
                  const SizedBox(height: 8),
                  if (wordScore != null && timeBonus != null) ...[
                    Text('Word score: $wordScore'),
                    Text('Time bonus: $timeBonus'),
                    const SizedBox(height: 4),
                    Text('Total: $serverScore',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ] else
                    Text('Your score: $serverScore'),
                ],
              )
            : const Text('Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Return to previous screen (menu/results)
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        _uiTimer?.cancel();
        await _submitWords(auto: true);
      }
    });
  }
}
