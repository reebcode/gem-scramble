import 'package:flutter/material.dart';
import '../services/matchmaking_service.dart';

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
    try {
      final details =
          await MatchmakingService.instance.getMatchDetails(widget.matchId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Match Details';
    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
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

    // Build up to 7 slots
    const totalSlots = 7;
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
        slots.add(_playerTile(
          title: isMe ? '$name (You)' : name,
          status: submitted ? 'Submitted' : 'Playing...',
          score: submitted ? score : null,
          highlight: isMe,
        ));
      } else {
        slots.add(_playerTile(
          title: 'Waiting for player...',
          status: 'Open slot',
          score: null,
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
          const SizedBox(height: 12),
          ...slots.map((w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: w,
              )),
        ],
      ),
    );
  }

  Widget _playerTile({
    required String title,
    required String status,
    int? score,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }
}
