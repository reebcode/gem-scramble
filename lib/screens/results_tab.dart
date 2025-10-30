import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:async';
import '../models/match.dart';
import 'match_details_screen.dart';

class ResultsTab extends StatefulWidget {
  const ResultsTab({super.key});

  @override
  State<ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<ResultsTab> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;
  List<Match> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
    // light polling to reflect new results shortly after games end
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _load();
    });
  }

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getMyMatches();
      setState(() {
        _matches = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
    if (_matches.isEmpty) {
      return const Center(
        child: Text('No matches yet. Play a game to see results!'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final m = _matches[i];
          final status = m.completed
              ? 'Completed'
              : (m.startedAt != null ? 'In Progress' : 'Waiting');
          final isPending = !m.completed;
          final myWin = isPending
              ? 'PENDING'
              : (m.isWinner ? 'WIN' : (m.isDraw ? 'DRAW' : 'LOSS'));
          return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MatchDetailsScreen(
                      matchId: m.matchId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.grey
                            : (m.isWinner
                                ? Colors.green
                                : (m.isDraw ? Colors.orange : Colors.red)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: isPending
                          ? const Icon(
                              Icons.hourglass_empty,
                              color: Colors.white,
                              size: 22,
                            )
                          : Text(
                              myWin,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Lobby: ${m.lobbyId} • ${m.gameDuration}s • ${m.board.length}x${m.board.length}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('You: ${m.myScore}',
                              style: const TextStyle(color: Colors.white70)),
                          Text("Opponent: ${m.opponentScore}",
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 2),
                          Text(status,
                              style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('\$${(m.myPrize / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                            color:
                                m.myPrize > 0 ? Colors.green : Colors.white70)),
                  ],
                ),
              ));
        },
      ),
    );
  }
}
