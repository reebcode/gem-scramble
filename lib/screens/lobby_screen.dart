import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../models/lobby.dart';
import '../providers/game_session_provider.dart';
import '../providers/lobby_provider.dart';
import '../providers/wallet_provider.dart';
import 'game_board_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    // Load once the first frame is ready; the provider handles re-entrancy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LobbyProvider>().loadLobbies();
    });
  }

  Future<void> _joinLobby(Lobby lobby) async {
    final wallet = context.read<WalletProvider>();
    final session = context.read<GameSessionProvider>();

    if (wallet.totalGemBalance < lobby.entryFee) {
      _showInsufficientFundsDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await session.joinLobby(
      lobby.lobbyId,
      playerName: wallet.user?.username,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    switch (result) {
      case Success():
        // Entry fee was debited server-side; reflect it immediately.
        wallet.refreshUser();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const GameBoardScreen(),
          ),
        );
      case Failure(:final message):
        _showErrorDialog('Failed to join lobby: $message');
    }
  }

  void _showInsufficientFundsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Gems'),
        content: const Text(
            'You don\'t have enough gems to join this lobby. Please earn more gems!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/wallet');
            },
            child: const Text('View Wallet'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gem Scramble'),
        centerTitle: true,
        actions: [
          // Rebuilds whenever the wallet changes (e.g. after entry fees).
          Consumer<WalletProvider>(
            builder: (context, wallet, _) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    wallet.user?.formattedGemBalance ?? '0 gems',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final lobbyState = context.watch<LobbyProvider>();

    if (lobbyState.isLoading && lobbyState.lobbies.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (lobbyState.error != null && lobbyState.lobbies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading lobbies',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              lobbyState.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<LobbyProvider>().loadLobbies(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LobbyProvider>().loadLobbies(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lobbyState.lobbies.length,
        itemBuilder: (context, index) {
          final lobby = lobbyState.lobbies[index];
          return _buildLobbyCard(lobby);
        },
      ),
    );
  }

  Widget _buildLobbyCard(Lobby lobby) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showPayoutDialog(lobby),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lobby.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFFFFD700),
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Entry',
                      lobby.formattedEntryFee,
                      Icons.diamond,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Total',
                      lobby.formattedPrizePool,
                      Icons.emoji_events,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Difficulty',
                      lobby.difficulty.toUpperCase(),
                      Icons.speed,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Board Size',
                      '${lobby.boardSize}x${lobby.boardSize}',
                      Icons.grid_view,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Players: ${lobby.currentPlayers}/${lobby.maxPlayers}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _joinLobby(lobby),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Join Game'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  void _showPayoutDialog(Lobby lobby) {
    // Calculate payouts using actual multipliers (same logic as backend)
    final multipliers = lobby.payoutMultipliers;
    final totalPrize = lobby.prizePool;
    final maxPayoutRanks = multipliers.length;

    final weightSum = multipliers.fold<double>(0.0, (sum, m) => sum + m);

    final payouts = <int>[];
    int distributed = 0;

    for (int i = 0; i < maxPayoutRanks; i++) {
      final amount = ((totalPrize * multipliers[i]) / weightSum).floor();
      payouts.add(amount);
      distributed += amount;
    }

    // Add remainder to 1st place
    final remainder = totalPrize - distributed;
    if (remainder > 0 && payouts.isNotEmpty) {
      payouts[0] += remainder;
    }

    String fmt(int gems) => '$gems gems';

    final payoutTexts = <Widget>[];
    for (int i = 0; i < payouts.length; i++) {
      final place = i + 1;
      final suffix = place == 1
          ? 'st'
          : place == 2
              ? 'nd'
              : place == 3
                  ? 'rd'
                  : 'th';
      payoutTexts.add(Text('$place$suffix place: ${fmt(payouts[i])}'));
    }

    final expectedTotal = lobby.entryFee * lobby.maxPlayers;
    final matchesText = expectedTotal == totalPrize
        ? 'Total prize pool matches entry fees (${lobby.entryFee} × ${lobby.maxPlayers})'
        : 'Total prize pool: $totalPrize (expected: $expectedTotal)';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${lobby.name} Gem Rewards'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entry Fee: ${lobby.formattedEntryFee}'),
              Text('Max Players: ${lobby.maxPlayers}'),
              Text('Total Prize Pool: ${lobby.formattedGemPool}'),
              Text(matchesText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              const Text('Payouts:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...payoutTexts,
              if (lobby.maxPlayers > payouts.length)
                Text(
                  'Places ${payouts.length + 1}-${lobby.maxPlayers}: 0 gems',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const SizedBox(height: 12),
              const Text('Click Join to enter the lobby.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _joinLobby(lobby);
            },
            child: const Text('Join Game'),
          ),
        ],
      ),
    );
  }
}
