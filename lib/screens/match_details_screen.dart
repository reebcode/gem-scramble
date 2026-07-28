import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repositories/match_repository.dart';

class MatchDetailsScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailsScreen({super.key, required this.matchId});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await context.read<MatchRepository>().getMatchDetails(widget.matchId);
    if (!mounted) return;
    setState(() {
      result.when(
        success: (details) => _details = details,
        failure: (message) => _error = message,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
      backgroundColor: const Color(0xFF1A1A1A),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final details = _details ?? <String, dynamic>{};
    final status = (details['status'] as String?) ?? 'unknown';
    final players = (details['players'] is List)
        ? List<Map<String, dynamic>>.from(details['players'] as List)
        : <Map<String, dynamic>>[];
    final me = players.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['isCurrentUser'] == true,
          orElse: () => null,
        );
    final myScore = (me != null && me['score'] is int) ? me['score'] as int : 0;
    final myWords = _stringList(me?['words']);

    final isCompleted = status.toLowerCase() == 'completed';
    final maxPlayers = (details['maxPlayers'] as int?) ?? players.length;
    final totalSlots = isCompleted ? players.length : maxPlayers;

    final board = _parseBoard(details['board']);
    final allPossible = _stringList(details['allPossibleWords']);
    final wordStats = details['wordStats'] is Map
        ? Map<String, dynamic>.from(details['wordStats'] as Map)
        : null;
    final foundSet = myWords.map((w) => w.toUpperCase()).toSet();

    final slots = <Widget>[];
    for (int i = 0; i < totalSlots; i++) {
      if (i < players.length) {
        final p = players[i];
        final name = (p['name'] as String?)?.isNotEmpty == true
            ? p['name'] as String
            : 'Player';
        final submitted = p['submittedAt'] != null;
        final score = (p['score'] is int) ? p['score'] as int : 0;
        final isMe = p['isCurrentUser'] == true;
        final rank = (p['rank'] as int?);
        final winnings = (p['winnings'] as num?)?.toInt();
        final words = _stringList(p['words']);

        String statusText;
        if (isCompleted && submitted) {
          if (rank != null) {
            final rankSuffix = rank == 1
                ? 'st'
                : rank == 2
                    ? 'nd'
                    : rank == 3
                        ? 'rd'
                        : 'th';
            statusText = '$rank$rankSuffix place';
            if (winnings != null && winnings > 0) {
              statusText += ' • $winnings gems';
            }
          } else {
            statusText = 'Submitted';
          }
        } else if (submitted) {
          statusText = 'Submitted';
        } else {
          statusText = 'Playing...';
        }

        slots.add(_playerTile(
          title: isMe ? '$name (You)' : name,
          status: statusText,
          score: submitted ? score : null,
          words: submitted ? words : const [],
          highlight: isMe,
        ));
      } else if (!isCompleted) {
        slots.add(_playerTile(
          title: 'Waiting for player...',
          status: 'Open slot',
          score: null,
          words: const [],
          highlight: false,
        ));
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status: ${status.toUpperCase()}',
                style: const TextStyle(color: Colors.white70),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Your Score: $myScore',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          if (board != null) ...[
            const SizedBox(height: 16),
            _sectionTitle('Board'),
            const SizedBox(height: 8),
            _boardPreview(board),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Players'),
          const SizedBox(height: 8),
          ...slots.map((w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: w,
              )),
          if (allPossible.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle(
              'All possible words (${allPossible.length})',
            ),
            if (wordStats != null) ...[
              const SizedBox(height: 6),
              Text(
                _statsLine(wordStats),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Found ${foundSet.intersection(allPossible.toSet()).length} of ${allPossible.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _wordChips(allPossible, foundSet),
          ] else if (me?['submittedAt'] == null && !isCompleted) ...[
            const SizedBox(height: 20),
            const Text(
              'Submit your words to reveal every valid word on this board.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  String _statsLine(Map<String, dynamic> stats) {
    final total = stats['total'] ?? 0;
    final l4 = stats['len4Plus'] ?? 0;
    final l5 = stats['len5Plus'] ?? 0;
    final l6 = stats['len6Plus'] ?? 0;
    return '$total total · $l4 of 4+ · $l5 of 5+ · $l6 of 6+';
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _boardPreview(List<List<String>> board) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFD700)),
      ),
      child: Column(
        children: board
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row
                      .map(
                        (cell) => Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0x66FFD700)),
                          ),
                          child: Text(
                            cell,
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _playerTile({
    required String title,
    required String status,
    int? score,
    required List<String> words,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? const Color(0xFFFFD700) : const Color(0x33FFD700),
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (score != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (words.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${words.length} words',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _wordChips(words, words.map((w) => w.toUpperCase()).toSet(),
                highlightFound: false),
          ],
        ],
      ),
    );
  }

  Widget _wordChips(
    List<String> words,
    Set<String> foundSet, {
    bool highlightFound = true,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: words.map((raw) {
        final word = raw.toUpperCase();
        final found = highlightFound && foundSet.contains(word);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: found ? const Color(0x33FFD700) : const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: found ? const Color(0xFFFFD700) : const Color(0x33FFFFFF),
            ),
          ),
          child: Text(
            word,
            style: TextStyle(
              color: found ? const Color(0xFFFFD700) : Colors.white70,
              fontSize: 12,
              fontWeight: found ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  List<List<String>>? _parseBoard(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    try {
      return value
          .map((row) =>
              (row as List).map((cell) => cell.toString()).toList())
          .toList();
    } catch (_) {
      return null;
    }
  }
}
