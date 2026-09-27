import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../solana_pay/models/solana_pay_request.dart';

class OfflinePaymentIntent {
  final SolanaPayRequest request;
  final String payerPublicKey;

  const OfflinePaymentIntent({
    required this.request,
    required this.payerPublicKey,
  });

  Map<String, dynamic> toJson() => {
        'recipient': request.recipient,
        'amount': request.amount,
        'reference': request.reference,
        'label': request.label,
        'message': request.message,
        'timestampMs': request.timestampMs,
        'payerPublicKey': payerPublicKey,
      };

  factory OfflinePaymentIntent.fromJson(Map<String, dynamic> json) {
    return OfflinePaymentIntent(
      request: SolanaPayRequest(
        recipient: json['recipient'] as String,
        amount: (json['amount'] as num).toDouble(),
        reference: json['reference'] as String,
        label: json['label'] as String? ?? 'APTO Merchant',
        message: json['message'] as String? ?? 'NFC Tap-to-Pay Transfer',
        timestampMs: json['timestampMs'] as int,
      ),
      payerPublicKey: json['payerPublicKey'] as String,
    );
  }
}

class OfflineIntentStore {
  static const _storageKey = 'apto_pending_payment_intents';
  static const _storage = FlutterSecureStorage();

  static Future<List<OfflinePaymentIntent>> readAll() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return <OfflinePaymentIntent>[];

    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .map((value) => OfflinePaymentIntent.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .toList();
    } catch (_) {
      await _storage.delete(key: _storageKey);
      return <OfflinePaymentIntent>[];
    }
  }

  static Future<void> add(OfflinePaymentIntent intent) async {
    final intents = List<OfflinePaymentIntent>.from(await readAll());
    intents.add(intent);
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(intents.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> remove(OfflinePaymentIntent intent) async {
    final intents = List<OfflinePaymentIntent>.from(await readAll());
    intents.removeWhere((item) =>
        item.request.reference == intent.request.reference &&
        item.payerPublicKey == intent.payerPublicKey);
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(intents.map((item) => item.toJson()).toList()),
    );
  }
}
