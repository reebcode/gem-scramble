import 'package:flutter/material.dart';
import '../models/lobby.dart';
import '../models/user.dart';
import '../services/wallet_service.dart';
import '../services/matchmaking_service.dart';
import '../services/api_service.dart';
import 'game_board_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final WalletService _walletService = WalletService.instance;
  final MatchmakingService _matchmakingService = MatchmakingService.instance;
  final ApiService _apiService = ApiService.instance;

  List<Lobby> _lobbies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWallet();
    _loadLobbies();
  }

  Future<void> _initializeWallet() async {
    await _walletService.ensureInitialized();
  }

  Future<void> _loadLobbies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _apiService.getLobbies();
      setState(() {
        _lobbies = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _joinLobby(Lobby lobby) async {
    // Check if user has sufficient gems
    final totalAvailable = _walletService.gemBalance;
    if (totalAvailable < lobby.entryFee) {
      _showInsufficientFundsDialog();
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final match = await _matchmakingService.joinLobby(lobby.lobbyId);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (match != null) {
          // Navigate to game screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameBoardScreen(match: match),
            ),
          );
        } else {
          _showErrorDialog('Failed to join lobby. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorDialog('Error joining lobby: $e');
      }
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
              // Navigate to wallet screen
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
          StreamBuilder<User?>(
            stream: _walletService.userStream,
            builder: (context, snapshot) {
              final user = snapshot.data;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    user?.formattedGemBalance ?? '0 gems',
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
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
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLobbies,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLobbies,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lobbies.length,
        itemBuilder: (context, index) {
          final lobby = _lobbies[index];
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
    final totalCents = lobby.prizePool;
    final firstCents = ((totalCents * 60) / 100).round();
    final secondCents = ((totalCents * 30) / 100).round();
    final thirdCents = totalCents - firstCents - secondCents;
    String fmt(int gems) => '$gems gems';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${lobby.name} Gem Rewards'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${lobby.formattedGemPool}'),
            const SizedBox(height: 8),
            Text('1st place: ${fmt(firstCents)}'),
            Text('2nd place: ${fmt(secondCents)}'),
            Text('3rd place: ${fmt(thirdCents)}'),
            const SizedBox(height: 12),
            const Text('Click Join to enter the lobby.'),
          ],
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
