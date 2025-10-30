import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../services/wallet_service.dart';
import '../components/animated_button.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  final WalletService _walletService = WalletService.instance;
  // Payment integration disabled for now

  late TabController _tabController;
  List<Transaction> _transactions = [];
  bool _isLoadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      await _walletService.ensureInitialized();
      await _walletService.refreshTransactions();
      setState(() {
        _transactions = _walletService.transactions;
        _isLoadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTransactions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Balance', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBalanceTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildBalanceTab() {
    return StreamBuilder<User?>(
      stream: _walletService.userStream,
      initialData: _walletService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? _walletService.currentUser;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Cards
              _buildBalanceCard(
                'Total Gems',
                user?.formattedTotalGemBalance ?? '0 gems',
                const Color(0xFFFFD700),
                Icons.diamond,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildBalanceCard(
                      'Gems',
                      user?.formattedGemBalance ?? '0 gems',
                      Colors.green,
                      Icons.account_balance,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBalanceCard(
                      'Bonus Gems',
                      user?.formattedBonusGemBalance ?? '0 bonus gems',
                      Colors.orange,
                      Icons.card_giftcard,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildBalanceCard(
                'Gems',
                '${user?.gems ?? 0}',
                Colors.purple,
                Icons.diamond,
              ),
              const SizedBox(height: 32),

              // Action Buttons
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Payment actions temporarily disabled
              const SizedBox(height: 16),
              AnimatedButton(
                text: 'Payments coming soon',
                icon: Icons.lock,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
                backgroundColor: Colors.grey,
                width: double.infinity,
              ),
              const SizedBox(height: 16),
              AnimatedButton(
                text: 'Buy Gems (coming soon)',
                icon: Icons.diamond,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
                backgroundColor: Colors.purple,
                width: double.infinity,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(
      String title, String amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: _isLoadingTransactions
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return _buildTransactionCard(transaction);
                  },
                ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getTransactionColor(transaction).withAlpha(51),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTransactionIcon(transaction),
            color: _getTransactionColor(transaction),
          ),
        ),
        title: Text(
          _getTransactionTitle(transaction),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.description ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              _formatDate(transaction.timestamp),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Text(
          transaction.formattedAmount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: transaction.isPositive ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Color _getTransactionColor(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.deposit:
        return Colors.green;
      case TransactionType.withdrawal:
        return Colors.blue;
      case TransactionType.prize:
        return Colors.amber;
      case TransactionType.bonus:
        return Colors.orange;
      case TransactionType.entryFee:
        return Colors.red;
      case TransactionType.refund:
        return Colors.purple;
    }
  }

  IconData _getTransactionIcon(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.deposit:
        return Icons.add_circle;
      case TransactionType.withdrawal:
        return Icons.remove_circle;
      case TransactionType.prize:
        return Icons.emoji_events;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.entryFee:
        return Icons.sports_esports;
      case TransactionType.refund:
        return Icons.refresh;
    }
  }

  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.prize:
        return 'Prize Won';
      case TransactionType.bonus:
        return 'Bonus';
      case TransactionType.entryFee:
        return 'Entry Fee';
      case TransactionType.refund:
        return 'Refund';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Payment dialogs disabled
}

// Payment dialogs removed while payment backend is not ready
