enum TransactionType {
  deposit,
  withdrawal,
  bonus,
  prize,
  entryFee,
  refund,
}

enum Currency {
  gems,
  bonusGems,
}

class Transaction {
  final String txId;
  final TransactionType type;
  final int amount;
  final Currency currency;
  final DateTime timestamp;
  final String? description;
  final String? matchId;
  final String? lobbyId;
  final String status; // pending, completed, failed, cancelled

  const Transaction({
    required this.txId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.timestamp,
    this.description,
    this.matchId,
    this.lobbyId,
    required this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      txId: json['txId'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.deposit,
      ),
      amount: json['amount'] as int,
      currency: Currency.values.firstWhere(
        (e) => e.name == json['currency'],
        orElse: () => Currency.gems,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      description: json['description'] as String?,
      matchId: json['matchId'] as String?,
      lobbyId: json['lobbyId'] as String?,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'txId': txId,
      'type': type.name,
      'amount': amount,
      'currency': currency.name,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'matchId': matchId,
      'lobbyId': lobbyId,
      'status': status,
    };
  }

  Transaction copyWith({
    String? txId,
    TransactionType? type,
    int? amount,
    Currency? currency,
    DateTime? timestamp,
    String? description,
    String? matchId,
    String? lobbyId,
    String? status,
  }) {
    return Transaction(
      txId: txId ?? this.txId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      matchId: matchId ?? this.matchId,
      lobbyId: lobbyId ?? this.lobbyId,
      status: status ?? this.status,
    );
  }

  bool get isPositive => amount > 0;
  bool get isNegative => amount < 0;
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  String get formattedAmount {
    final sign = isPositive ? '+' : '';
    return '$sign\$${(amount / 100).toStringAsFixed(2)}';
  }

  @override
  String toString() {
    return 'Transaction(txId: $txId, type: $type, amount: $amount, currency: $currency, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction && other.txId == txId;
  }

  @override
  int get hashCode => txId.hashCode;
}
