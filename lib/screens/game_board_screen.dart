import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../game/scramble_game.dart';
import '../providers/game_session_provider.dart';
import '../providers/wallet_provider.dart';

/// Renders the active game session. All match/timer/word state lives in
/// [GameSessionProvider]; this widget only draws and dispatches intents.
class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({super.key});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  ScrambleGame? _game;
  bool _autoSubmitTriggered = false;

  GameSessionProvider get _session => context.read<GameSessionProvider>();

  void _safeSetCurrentWord(String word) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _session.setCurrentWord(word);
      });
    } else {
      _session.setCurrentWord(word);
    }
  }

  void _safeAddWordFromGame(String word, int score, Rect tileRect) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addWord(word, tileRect);
    });
  }

  Future<void> _addWord(String word, Rect startRect) async {
    final outcome = await _session.tryAddWord(word);
    if (!mounted) return;

    switch (outcome) {
      case AddWordOutcome.accepted:
        final points = word.length * word.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found: ${word.toUpperCase()} (+$points points)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        _game?.triggerConfettiExplosion(startRect.center);
      case AddWordOutcome.rejected:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${word.toUpperCase()} is not valid'),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 800),
          ),
        );
      case AddWordOutcome.duplicate:
      case AddWordOutcome.error:
        break;
    }
  }

  Future<void> _submitWords({bool auto = false}) async {
    final session = _session;
    if (session.isSubmitting || session.hasSubmitted) return;

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

    final wordCount = session.foundWords.length;
    final result = await session.submitWords();
    if (!mounted) return;

    // Winnings may already be credited if this submission completed the match.
    context.read<WalletProvider>().refreshUser();

    final ok = result.isSuccess;
    final updated = session.match;
    final serverScore = result.valueOrNull ?? session.clientScore;
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
                  Text('Submitted: $wordCount words'),
                  const SizedBox(height: 8),
                  if (wordScore != null && timeBonus != null) ...[
                    Text('Word score: $wordScore'),
                    Text('Time bonus: $timeBonus'),
                    const SizedBox(height: 4),
                    Text('Total: ${updated?.myScore ?? serverScore}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ] else
                    Text('Your score: $serverScore'),
                ],
              )
            : Text(result.errorOrNull ?? 'Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _maybeAutoSubmit(GameSessionProvider session) {
    if (_autoSubmitTriggered ||
        !session.isTimeExpired ||
        session.hasSubmitted ||
        session.isSubmitting ||
        session.match == null) {
      return;
    }
    _autoSubmitTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submitWords(auto: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionProvider>();
    final match = session.match;

    if (match == null) {
      // Session was reset (e.g. left the match); nothing to render.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _maybeAutoSubmit(session);

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
                      '${session.timeRemaining}s',
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
                    'Score: ${session.clientScore}',
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
                    board: match.board,
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
                    session.currentWord.isEmpty
                        ? 'Tap letters to form words'
                        : session.currentWord,
                    style: TextStyle(
                      fontSize: 16,
                      color: session.currentWord.isEmpty
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
                          'Found Words (${session.foundWords.length})',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (session.foundWords.isNotEmpty)
                          ElevatedButton(
                            onPressed: session.isSubmitting
                                ? null
                                : () => _submitWords(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: const Color(0xFFFFD700),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                            child: session.isSubmitting
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
                    child: session.foundWords.isEmpty
                        ? const Center(
                            child: Text(
                              'No words found yet.\nTap letters to form words!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: session.foundWords.length,
                            itemBuilder: (context, index) {
                              final word = session.foundWords[index];
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
}
