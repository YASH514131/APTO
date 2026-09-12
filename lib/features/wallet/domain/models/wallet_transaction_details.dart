class WalletTransactionDetails {
  final String signature;
  final int slot;
  final int? blockTime;
  final int? feeLamports;
  final bool isSuccessful;

  const WalletTransactionDetails({
    required this.signature,
    required this.slot,
    required this.blockTime,
    required this.feeLamports,
    required this.isSuccessful,
  });
}
