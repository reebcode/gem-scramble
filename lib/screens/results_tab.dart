import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/match_history_provider.dart';
import 'match_details_screen.dart';

class ResultsTab extends StatefulWidget {
  const ResultsTab({super.key});

  @override
  State<ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<ResultsTab> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MatchHistoryProvider>().loadMatches();
    });
    // Light polling so new results appear shortly after games end. Silent
    // refreshes keep showing the current list instead of a spinner.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<MatchHistoryProvider>().loadMatches(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<MatchHistoryProvider>();

    if (history.isLoading && !history.hasLoadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.error != null && history.matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(history.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  context.read<MatchHistoryProvider>().loadMatches(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (history.matches.isEmpty) {
      return const Center(
        child: Text('No matches yet. Play a game to see results!'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<MatchHistoryProvider>().loadMatches(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: history.matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final m = history.matches[i];
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
                    Text('${m.myPrize} gems',
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
