class ReceivedFundEvent {
  final double amountSol;
  final String tokenSymbol;
  final String senderAddress;
  final String signature;
  final DateTime timestamp;

  const ReceivedFundEvent({
    required this.amountSol,
    this.tokenSymbol = 'SOL',
    required this.senderAddress,
    required this.signature,
    required this.timestamp,
  });

  String get formattedAmount {
    if (amountSol >= 1.0) {
      return '+ ${amountSol.toStringAsFixed(3)} $tokenSymbol';
    } else {
      return '+ ${amountSol.toStringAsFixed(4)} $tokenSymbol';
    }
  }

  String get shortSender {
    if (senderAddress.isEmpty) return 'Unknown Sender';
    if (senderAddress.length <= 10) return senderAddress;
    return '${senderAddress.substring(0, 4)}...${senderAddress.substring(senderAddress.length - 4)}';
  }

  String get shortSignature {
    if (signature.isEmpty) return '';
    if (signature.length <= 10) return signature;
    return '${signature.substring(0, 4)}...${signature.substring(signature.length - 4)}';
  }
}
