import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/models/wallet_transaction.dart';
import 'financial_insights_service.dart';

class AptoTransactionStore {
  static const _storageKey = 'apto_local_transactions';
  static const _storage = FlutterSecureStorage();

  static Future<List<WalletTransaction>> readAll() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return <WalletTransaction>[];

      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .map((v) => WalletTransaction.fromJson(
              Map<String, dynamic>.from(v as Map)))
          .toList();
    } catch (_) {
      return <WalletTransaction>[];
    }
  }

  static Future<void> record(WalletTransaction tx) async {
    try {
      final list = List<WalletTransaction>.from(await readAll());
      // Avoid duplicate signatures
      list.removeWhere((item) => item.signature == tx.signature);
      list.insert(0, tx);
      // Keep most recent 50
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(list.map((item) => item.toJson()).toList()),
      );
      FinancialInsightsService.instance.recordTransaction(tx);
    } catch (_) {}
  }

  static Future<WalletTransaction?> findBySignature(String signature) async {
    final list = await readAll();
    for (final tx in list) {
      if (tx.signature == signature) return tx;
    }
    return null;
  }
}
