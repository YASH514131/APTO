enum TransactionType {
  sent,
  received,
}

class WalletTransaction {
  final String signature;
  final String? memo;
  final int? blockTime;
  final bool isSuccessful;
  final double amount;
  final TransactionType type;
  final String counterparty;

  const WalletTransaction({
    required this.signature,
    required this.memo,
    required this.blockTime,
    required this.isSuccessful,
    this.amount = 0.0,
    this.type = TransactionType.received,
    this.counterparty = '',
  });

  bool get isSent => type == TransactionType.sent;
  bool get isReceived => type == TransactionType.received;

  String get formattedAmount {
    final prefix = isSent ? '-' : '+';
    final amt = amount > 0 ? amount.toStringAsFixed(3) : '0.000';
    return '$prefix$amt SOL';
  }

  String get shortCounterparty {
    if (counterparty.isEmpty) return '';
    if (counterparty.length <= 10) return counterparty;
    return '${counterparty.substring(0, 4)}...${counterparty.substring(counterparty.length - 4)}';
  }

  String get title {
    if (memo != null && memo!.isNotEmpty && memo != 'Solana transaction') {
      return memo!;
    }
    if (isSent) {
      return shortCounterparty.isNotEmpty ? 'Sent to $shortCounterparty' : 'Sent SOL';
    } else {
      return shortCounterparty.isNotEmpty ? 'Received from $shortCounterparty' : 'Received SOL';
    }
  }

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'memo': memo,
        'blockTime': blockTime,
        'isSuccessful': isSuccessful,
        'amount': amount,
        'type': type.name,
        'counterparty': counterparty,
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        signature: json['signature'] as String? ?? '',
        memo: json['memo'] as String?,
        blockTime: json['blockTime'] as int?,
        isSuccessful: json['isSuccessful'] as bool? ?? true,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        type: json['type'] == 'sent'
            ? TransactionType.sent
            : TransactionType.received,
        counterparty: json['counterparty'] as String? ?? '',
      );
}
