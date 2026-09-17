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
    return 'solana:$recipient?amount=$amount&reference=$reference&label=${Uri.encodeComponent(label)}&message=${Uri.encodeComponent(message)}';
  }

  SolanaPayRequest withAmount(double value, {int? timestamp}) {
    return SolanaPayRequest(
      recipient: recipient,
      amount: value,
      reference: reference,
      label: label,
      message: message,
      timestampMs: timestamp ?? timestampMs,
      isAddressOnly: false,
    );
  }

  /// Parses APDU byte response payload in format: "PAYLOAD|TIMESTAMP"
  factory SolanaPayRequest.fromApduString(String rawString) {
    final parts = rawString.split('|');
    if (parts.length < 2) {
      throw FormatException('Invalid APDU payload format: $rawString');
    }

    final urlString = parts[0];
    final timestampMs =
        int.tryParse(parts[1]) ?? DateTime.now().millisecondsSinceEpoch;

    final uri = Uri.parse(urlString);
    final recipient = uri.path.replaceAll('solana:', '');
    final amount =
        double.tryParse(uri.queryParameters['amount'] ?? '0.0') ?? 0.0;
    final reference = uri.queryParameters['reference'] ?? '';
    final label = uri.queryParameters['label'] ?? 'APTO Merchant';
    final message = uri.queryParameters['message'] ?? 'NFC Tap-to-Pay';
    final isAddressOnly = uri.queryParameters['mode'] == 'address';

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
