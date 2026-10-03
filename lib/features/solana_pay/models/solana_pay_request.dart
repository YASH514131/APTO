class SolanaPayRequest {
  final String recipient;
  final double amount;
  final String reference;
  final String label;
  final String message;
  final int timestampMs;
  final bool isAddressOnly;

  SolanaPayRequest({
    required this.recipient,
    required this.amount,
    required this.reference,
    this.label = 'APTO Merchant',
    this.message = 'NFC Tap-to-Pay Transfer',
    required this.timestampMs,
    this.isAddressOnly = false,
  });

  /// Constructs a standard Solana Pay URL string
  String toSolanaPayUrl() {
    final refPart = reference.trim().isNotEmpty ? '&reference=${reference.trim()}' : '';
    return 'solana:$recipient?amount=$amount$refPart&label=${Uri.encodeComponent(label)}&message=${Uri.encodeComponent(message)}';
  }

  SolanaPayRequest withAmount(double value, {int? timestamp, String? reference}) {
    return SolanaPayRequest(
      recipient: recipient,
      amount: value,
      reference: reference ?? this.reference,
      label: label,
      message: message,
      timestampMs: timestamp ?? timestampMs,
      isAddressOnly: false,
    );
  }

  /// Parses APDU byte response payload in format: "PAYLOAD|TIMESTAMP" or raw URL
  factory SolanaPayRequest.fromApduString(String rawString) {
    String urlString = rawString.trim();
    int timestampMs = DateTime.now().millisecondsSinceEpoch;

    final lastPipeIndex = urlString.lastIndexOf('|');
    if (lastPipeIndex != -1) {
      final potentialTimestamp =
          int.tryParse(urlString.substring(lastPipeIndex + 1));
      if (potentialTimestamp != null) {
        timestampMs = potentialTimestamp;
        urlString = urlString.substring(0, lastPipeIndex).trim();
      }
    }

    final uri = Uri.tryParse(urlString);
    String recipient = '';
    double amount = 0.0;
    String reference = '';
    String label = 'APTO Merchant';
    String message = 'NFC Tap-to-Pay';
    bool isAddressOnly = false;

    if (uri != null) {
      recipient =
          uri.path.replaceAll('solana:', '').replaceAll('/', '').trim();
      if (recipient.isEmpty && uri.host.isNotEmpty) {
        recipient = uri.host.trim();
      }
      amount =
          double.tryParse(uri.queryParameters['amount'] ?? '0.0') ?? 0.0;
      reference = uri.queryParameters['reference'] ?? '';
      label = uri.queryParameters['label'] ?? 'APTO Merchant';
      message = uri.queryParameters['message'] ?? 'NFC Tap-to-Pay';
      isAddressOnly =
          uri.queryParameters['mode'] == 'address' || amount <= 0.0;
    }

    if (recipient.isEmpty) {
      recipient = urlString
          .replaceAll('solana:', '')
          .split('?')
          .first
          .replaceAll('/', '')
          .trim();
      isAddressOnly = true;
    }

    return SolanaPayRequest(
      recipient: recipient,
      amount: amount,
      reference: reference,
      label: label,
      message: message,
      timestampMs: timestampMs,
      isAddressOnly: isAddressOnly,
    );
  }
}
