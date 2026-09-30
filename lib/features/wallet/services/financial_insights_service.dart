import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';
import '../../../core/constants/solana_config.dart';
import '../domain/models/financial_insights.dart';
import '../domain/models/wallet_transaction.dart';
import 'apto_transaction_store.dart';
import 'wallet_adapter_service.dart';

enum FinancialInsightsSyncStatus {
  ready,
  checking,
  collecting,
  synced,
  retryPending,
}

/// Service responsible for computing and persistently caching financial insights:
/// - Total Received SOL (sum of all incoming balance deltas for the connected wallet)
/// - Total Spent SOL (sum of all outgoing balance deltas for the connected wallet)
/// - Total Network Fees paid (sum of all transaction fees paid by the wallet)
///
/// Features:
/// - Direct client-side Solana Devnet RPC scanning (saving backend rate limits and cold starts).
/// - Scans up to 100 on-chain transactions for full financial accounting.
/// - Accurately extracts account pubkeys from static and loaded address lookup tables.
/// - Computes exact preBalances and postBalances per account index.
/// - Caches each parsed transaction permanently in local persistent storage so RPC calls are only made for NEW transactions.
class FinancialInsightsService {
  static final FinancialInsightsService instance =
      FinancialInsightsService._internal();

  FinancialInsightsService._internal();

  final ValueNotifier<FinancialInsights> insightsNotifier =
      ValueNotifier<FinancialInsights>(FinancialInsights.empty());

  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<FinancialInsightsSyncStatus> syncStatusNotifier =
      ValueNotifier<FinancialInsightsSyncStatus>(
    FinancialInsightsSyncStatus.checking,
  );

  static const String _summaryCachePrefix = 'apto_financial_flow_summary_v4_';
  static const String _txDetailsCachePrefix = 'apto_financial_flow_txs_v5_';
  static const String _lastScanEpochPrefix =
      'apto_financial_flow_last_scan_v5_';
  static const String _scanCursorPrefix = 'apto_financial_flow_scan_cursor_v2_';
  static const String _scanInProgressPrefix =
      'apto_financial_flow_scan_in_progress_v1_';

  /// Scan public Devnet at most twice per rolling 24-hour period.
  static const Duration updateInterval = Duration(hours: 12);

  Future<void>? _loadRequest;
  String? _loadRequestAddress;

  RpcClient get _rpcClient => RpcClient(SolanaConfig.devnetRpcUrl);

  /// Safely extracts the public key string from RawAccountKey, ParsedAccountKey, Map, or String
  static String extractAccountPubkey(dynamic key) {
    if (key == null) return '';
    if (key is String) return key;
    try {
      final dynamic pubkey = (key as dynamic).pubkey;
      if (pubkey != null) return pubkey.toString();
    } catch (_) {}
    if (key is Map && key['pubkey'] != null) {
      return key['pubkey'].toString();
    }
    return key.toString();
  }

  /// Loads local insights first, then syncs Devnet at most once every 12 hours.
  Future<void> loadInsights() {
    final address = WalletAdapterService.instance.fullAddressNotifier.value;
    if (address.isEmpty) {
      insightsNotifier.value = FinancialInsights.empty();
      syncStatusNotifier.value = FinancialInsightsSyncStatus.ready;
      return Future<void>.value();
    }

    if (_loadRequest != null && _loadRequestAddress == address) {
      return _loadRequest!;
    }

    syncStatusNotifier.value = FinancialInsightsSyncStatus.checking;
    _loadRequestAddress = address;
    final request = _loadInsights(address);
    _loadRequest = request;
    return request.whenComplete(() {
      if (identical(_loadRequest, request)) _loadRequest = null;
    });
  }

  Future<void> _loadInsights(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final summaryKey = '$_summaryCachePrefix$address';
    final txCacheKey = '$_txDetailsCachePrefix$address';
    final lastScanKey = '$_lastScanEpochPrefix$address';
    final scanCursorKey = '$_scanCursorPrefix$address';
    final scanInProgressKey = '$_scanInProgressPrefix$address';

    // 1. INSTANT LOCAL LOAD (0ms) - Never leave UI empty
    FinancialInsights? savedInsights;
    final rawSummary = prefs.getString(summaryKey);
    if (rawSummary != null && rawSummary.isNotEmpty) {
      try {
        savedInsights = FinancialInsights.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawSummary) as Map),
        );
      } catch (e) {
        debugPrint('Error decoding cached financial summary: $e');
      }
    }
    if (savedInsights != null) {
      insightsNotifier.value = savedInsights;
    }

    Map<String, dynamic> cachedTxMap = {};
    final rawTxCache = prefs.getString(txCacheKey);
    if (rawTxCache != null && rawTxCache.isNotEmpty) {
      try {
        cachedTxMap = Map<String, dynamic>.from(jsonDecode(rawTxCache) as Map);
      } catch (e) {
        debugPrint('Error decoding cached tx map: $e');
      }
    }
    cachedTxMap.remove('initial_funded_$address');
    final hasPersistedTxCache = cachedTxMap.isNotEmpty;

    // Integrate local transactions from AptoTransactionStore immediately
    try {
      final localTxs = await AptoTransactionStore.readAll();
      for (final tx in localTxs) {
        if (!cachedTxMap.containsKey(tx.signature)) {
          cachedTxMap[tx.signature] = {
            'amount': tx.amount,
            'isReceived': tx.isReceived,
            'fee': tx.isSent ? 0.000005 : 0.0,
            'blockTime':
                tx.blockTime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
            'onChain': false,
          };
        }
      }
    } catch (_) {}

    // Immediately compute and display local totals (0ms)
    final currentInsights = !hasPersistedTxCache && savedInsights != null
        ? savedInsights
        : computeTotalsFromMap(cachedTxMap);
    insightsNotifier.value = currentInsights;

    // Enforce the interval even when the cache is empty or a scan previously failed.
    final lastScanEpoch = prefs.getInt(lastScanKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final scanInProgress = prefs.getBool(scanInProgressKey) ?? false;
    if (!scanInProgress &&
        !isRefreshDue(lastScanEpoch: lastScanEpoch, nowEpoch: nowMs)) {
      syncStatusNotifier.value = lastScanEpoch > 0
          ? FinancialInsightsSyncStatus.synced
          : FinancialInsightsSyncStatus.ready;
      final elapsedMs = nowMs - lastScanEpoch;
      debugPrint('FinancialInsights: Using locally saved data. Last Devnet '
          'scan was ${(elapsedMs / (1000 * 60 * 60)).toStringAsFixed(1)} hrs ago.');
      return;
    }

    // Scan directly from public Devnet and persist progress page by page.
    syncStatusNotifier.value = FinancialInsightsSyncStatus.collecting;
    await prefs.setBool(scanInProgressKey, true);
    isLoadingNotifier.value = true;
    try {
      debugPrint(
          'FinancialInsights: Running 12-hour public Devnet sync for $address...');
      final scanCursor = prefs.getString(scanCursorKey);
      String? before;
      String? lastScannedSignature;
      var reachedCursor = false;
      var allPagesComplete = true;

      Future<void> publishProgress() async {
        final hasOnChainEntries = cachedTxMap.values.any(
          (entry) => entry is Map && entry['onChain'] == true,
        );
        if (cachedTxMap.isEmpty ||
            (!hasPersistedTxCache &&
                !hasOnChainEntries &&
                savedInsights != null)) {
          return;
        }

        final updatedInsights = computeTotalsFromMap(cachedTxMap);
        await prefs.setString(txCacheKey, jsonEncode(cachedTxMap));
        await prefs.setString(
          summaryKey,
          jsonEncode(updatedInsights.toJson()),
        );
        insightsNotifier.value = updatedInsights;
      }

      do {
        final signatures = await _rpcClient
            .getSignaturesForAddress(address, limit: 1000, before: before)
            .timeout(const Duration(seconds: 15));
        if (signatures.isEmpty) break;

        var pageComplete = true;
        var pendingProgressTransactions = 0;
        for (final sigInfo in signatures) {
          final sig = sigInfo.signature;
          if (sig == scanCursor) {
            reachedCursor = true;
            break;
          }
          if (cachedTxMap[sig]?['onChain'] == true) continue;
          pendingProgressTransactions++;

          try {
            // Polite delay between requests to prevent public Devnet 429 Too Many Requests
            await Future.delayed(const Duration(milliseconds: 100));

            final txDetails = await _rpcClient
                .getTransaction(sig)
                .timeout(const Duration(seconds: 4));

            if (txDetails != null && txDetails.meta != null) {
              final feeLamports = txDetails.meta!.fee;
              final feeSol = feeLamports / lamportsPerSol;

              final pre = txDetails.meta!.preBalances;
              final post = txDetails.meta!.postBalances;
              final dynamic txObj = txDetails.transaction;
              final dynamic msg = (txObj as dynamic).message;
              final dynamic accountKeys = msg?.accountKeys;

              int myIndex = -1;
              if (accountKeys is List) {
                for (var i = 0; i < accountKeys.length; i++) {
                  final pubkey = extractAccountPubkey(accountKeys[i]);
                  if (pubkey == address) {
                    myIndex = i;
                    break;
                  }
                }
              }

              // Also check address lookup table loaded addresses (v0 transactions)
              if (myIndex == -1 && txDetails.meta?.loadedAddresses != null) {
                final loaded = txDetails.meta!.loadedAddresses;
                final writable = loaded?.writable ?? const <String>[];
                final readonly = loaded?.readonly ?? const <String>[];
                final allLoaded = [...writable, ...readonly];
                for (var idx = 0; idx < allLoaded.length; idx++) {
                  if (allLoaded[idx] == address) {
                    myIndex =
                        (accountKeys is List ? accountKeys.length : 0) + idx;
                    break;
                  }
                }
              }

              if (myIndex >= 0 &&
                  myIndex < pre.length &&
                  myIndex < post.length) {
                final preBal = pre[myIndex];
                final postBal = post[myIndex];
                final delta = postBal - preBal;
                final isFeePayer = myIndex == 0;
                final paidFee = isFeePayer ? feeSol : 0.0;
                final hasErr =
                    txDetails.meta!.err != null || sigInfo.err != null;

                if (hasErr) {
                  // Failed transaction: transfer did not execute, only network fee was deducted
                  cachedTxMap[sig] = {
                    'amount': 0.0,
                    'isReceived': false,
                    'fee': paidFee,
                    'blockTime': sigInfo.blockTime ?? txDetails.blockTime,
                    'onChain': true,
                  };
                } else if (delta > 0) {
                  // Wallet RECEIVED funds
                  // Gross received = (delta + userPaidFeeLamports) / lamportsPerSol
                  final grossReceived =
                      (delta + (isFeePayer ? feeLamports : 0)) / lamportsPerSol;
                  cachedTxMap[sig] = {
                    'amount': grossReceived,
                    'isReceived': true,
                    'fee': paidFee,
                    'blockTime': sigInfo.blockTime ?? txDetails.blockTime,
                    'onChain': true,
                  };
                } else if (delta < 0) {
                  // Wallet SPENT funds or paid fee
                  final totalDeducted = delta.abs() / lamportsPerSol;
                  final pureSpent =
                      (totalDeducted - paidFee).clamp(0.0, double.infinity);

                  cachedTxMap[sig] = {
                    'amount': pureSpent,
                    'isReceived': false,
                    'fee': paidFee,
                    'blockTime': sigInfo.blockTime ?? txDetails.blockTime,
                    'onChain': true,
                  };
                } else {
                  // Balance delta was 0 lamports
                  cachedTxMap[sig] = {
                    'amount': 0.0,
                    'isReceived': false,
                    'fee': paidFee,
                    'blockTime': sigInfo.blockTime ?? txDetails.blockTime,
                    'onChain': true,
                  };
                }
              } else {
                pageComplete = false;
              }
            } else {
              pageComplete = false;
            }
          } catch (e) {
            pageComplete = false;
            debugPrint('Note parsing tx $sig for financial insights: $e');
          }

          if (pendingProgressTransactions >= 10) {
            await publishProgress();
            pendingProgressTransactions = 0;
          }
        }

        await publishProgress();
        if (!pageComplete) allPagesComplete = false;

        if (reachedCursor) break;
        before = signatures.last.signature;
        lastScannedSignature = before;
        if (signatures.length < 1000) break;
      } while (true);

      if (allPagesComplete) {
        if (!reachedCursor && lastScannedSignature != null) {
          await prefs.setString(scanCursorKey, lastScannedSignature);
        }
        await prefs.setInt(lastScanKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool(scanInProgressKey, false);
        syncStatusNotifier.value = FinancialInsightsSyncStatus.synced;
      } else {
        syncStatusNotifier.value = FinancialInsightsSyncStatus.retryPending;
      }
    } catch (e) {
      debugPrint('FinancialInsightsService Devnet scan note: $e');
      syncStatusNotifier.value = FinancialInsightsSyncStatus.retryPending;
      insightsNotifier.value = !hasPersistedTxCache && savedInsights != null
          ? currentInsights
          : computeTotalsFromMap(cachedTxMap);
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Calculates total received, total spent, and total fees across all parsed transactions
  @visibleForTesting
  static bool isRefreshDue({
    required int lastScanEpoch,
    required int nowEpoch,
  }) =>
      lastScanEpoch <= 0 ||
      nowEpoch - lastScanEpoch >= updateInterval.inMilliseconds;

  @visibleForTesting
  static FinancialInsights computeTotalsFromMap(Map<String, dynamic> txMap) {
    double totalReceived = 0.0;
    double totalSpent = 0.0;
    double totalFees = 0.0;

    for (final entry in txMap.values) {
      if (entry is Map) {
        final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
        final isReceived = entry['isReceived'] as bool? ?? false;
        final fee = (entry['fee'] as num?)?.toDouble() ?? 0.0;

        if (isReceived) {
          totalReceived += amount;
        } else {
          totalSpent += amount;
        }
        totalFees += fee;
      }
    }

    return FinancialInsights(
      totalReceived: totalReceived,
      totalSpent: totalSpent,
      totalFees: totalFees,
      transactionCount: txMap.length,
      lastUpdated: DateTime.now(),
      isFromCache: false,
    );
  }

  /// Immediately records a new transaction locally to update totals without waiting for RPC
  Future<void> recordTransaction(
    WalletTransaction tx, {
    double feeSol = 0.000005,
  }) async {
    final address = WalletAdapterService.instance.fullAddressNotifier.value;
    if (address.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final txCacheKey = '$_txDetailsCachePrefix$address';
    final summaryKey = '$_summaryCachePrefix$address';

    Map<String, dynamic> cachedTxMap = {};
    final rawTxCache = prefs.getString(txCacheKey);
    if (rawTxCache != null && rawTxCache.isNotEmpty) {
      try {
        cachedTxMap = Map<String, dynamic>.from(jsonDecode(rawTxCache) as Map);
      } catch (_) {}
    }

    cachedTxMap[tx.signature] = {
      'amount': tx.amount,
      'isReceived': tx.isReceived,
      'fee': tx.isSent ? feeSol : 0.0,
      'blockTime':
          tx.blockTime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    };

    final updated = computeTotalsFromMap(cachedTxMap);
    insightsNotifier.value = updated;

    await prefs.setString(txCacheKey, jsonEncode(cachedTxMap));
    await prefs.setString(summaryKey, jsonEncode(updated.toJson()));
  }
}
