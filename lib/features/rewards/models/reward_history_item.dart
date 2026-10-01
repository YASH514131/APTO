import 'dart:convert';

class RewardHistoryItem {
  final String id;
  final String title;
  final String dateText;
  final double amountSkr;
  final bool isCredit;
  final String? tier;
  final String? txSig;

  const RewardHistoryItem({
    required this.id,
    required this.title,
    required this.dateText,
    required this.amountSkr,
    this.isCredit = true,
    this.tier,
    this.txSig,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateText': dateText,
      'amountSkr': amountSkr,
      'isCredit': isCredit,
      'tier': tier,
      'txSig': txSig,
    };
  }

  factory RewardHistoryItem.fromMap(Map<String, dynamic> map) {
    return RewardHistoryItem(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Reward',
      dateText: map['dateText'] ?? '',
      amountSkr: (map['amountSkr'] as num?)?.toDouble() ?? 0.0,
      isCredit: map['isCredit'] ?? true,
      tier: map['tier'],
      txSig: map['txSig'],
    );
  }

  String toJson() => jsonEncode(toMap());
  factory RewardHistoryItem.fromJson(String source) =>
      RewardHistoryItem.fromMap(jsonDecode(source));
}
