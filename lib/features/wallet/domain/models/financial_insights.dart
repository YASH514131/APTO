/// Financial insights domain model representing aggregated totals and distribution.
class FinancialInsights {
  final double totalReceived;
  final double totalSpent;
  final double totalFees;
  final int transactionCount;
  final DateTime lastUpdated;
  final bool isFromCache;

  const FinancialInsights({
    this.totalReceived = 0.0,
    this.totalSpent = 0.0,
    this.totalFees = 0.0,
    this.transactionCount = 0,
    required this.lastUpdated,
    this.isFromCache = true,
  });

  /// Total SOL volume processed (received + spent + fees)
  double get totalVolume => totalReceived + totalSpent + totalFees;

  /// Distribution ratios between 0.0 and 1.0
  double get receivedRatio =>
      totalVolume > 0 ? (totalReceived / totalVolume).clamp(0.0, 1.0) : 0.0;

  double get spentRatio =>
      totalVolume > 0 ? (totalSpent / totalVolume).clamp(0.0, 1.0) : 0.0;

  double get feesRatio =>
      totalVolume > 0 ? (totalFees / totalVolume).clamp(0.0, 1.0) : 0.0;

  /// Net flow in SOL (Received - Spent - Fees)
  double get netFlow => totalReceived - totalSpent - totalFees;

  String get formattedReceived =>
      totalReceived > 0 ? '+${totalReceived.toStringAsFixed(3)} SOL' : '0.000 SOL';
  String get formattedSpent =>
      totalSpent > 0 ? '-${totalSpent.toStringAsFixed(3)} SOL' : '0.000 SOL';
  String get formattedFees =>
      totalFees > 0 ? '${totalFees.toStringAsFixed(5)} SOL' : '0.00000 SOL';

  String get formattedTotalVolume => '${totalVolume.toStringAsFixed(3)} SOL';
  String get formattedNetFlow {
    final prefix = netFlow > 0 ? '+' : '';
    return '$prefix${netFlow.toStringAsFixed(3)} SOL';
  }

  Map<String, dynamic> toJson() => {
        'totalReceived': totalReceived,
        'totalSpent': totalSpent,
        'totalFees': totalFees,
        'transactionCount': transactionCount,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      };

  factory FinancialInsights.fromJson(Map<String, dynamic> json) =>
      FinancialInsights(
        totalReceived: (json['totalReceived'] as num?)?.toDouble() ?? 0.0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
        totalFees: (json['totalFees'] as num?)?.toDouble() ?? 0.0,
        transactionCount: json['transactionCount'] as int? ?? 0,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
            : DateTime.now(),
        isFromCache: true,
      );

  static FinancialInsights empty() => FinancialInsights(
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
        isFromCache: false,
      );
}
