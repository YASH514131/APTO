class WalletTransaction {
  final String signature;
  final String? memo;
  final int? blockTime;
  final bool isSuccessful;

  const WalletTransaction({
    required this.signature,
    required this.memo,
    required this.blockTime,
    required this.isSuccessful,
  });
}
