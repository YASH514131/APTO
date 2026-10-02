import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';
import 'package:solana/base58.dart';
import '../domain/models/wallet_provider.dart';
import '../domain/models/wallet_transaction.dart';
import '../domain/models/wallet_transaction_details.dart';
import '../domain/models/financial_insights.dart';
import '../../solana_pay/services/mwa_signing_service.dart';
import '../../terminal/services/hce_service.dart';
import '../../../core/services/apto_backend_rpc_client.dart';
import '../../../core/services/apto_audio_service.dart';
import '../../../core/services/apto_fcm_service.dart';
import '../../../core/constants/solana_config.dart';
import 'apto_transaction_store.dart';
import 'financial_insights_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletAdapterService {
  static final WalletAdapterService instance = WalletAdapterService._internal();

  WalletAdapterService._internal();

  final ValueNotifier<WalletProvider> activeWalletNotifier =
      ValueNotifier<WalletProvider>(WalletProvider.seedVault);

  final ValueNotifier<String> fullAddressNotifier = ValueNotifier<String>('');

  final ValueNotifier<String> walletAddressNotifier = ValueNotifier<String>('');

  final ValueNotifier<double> solBalanceNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> usdcBalanceNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isBalanceLoadingNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastTransactionSignatureNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> lastTransactionErrorNotifier =
      ValueNotifier<String?>(null);

  static const _authTokenKey = 'mwa_auth_token';
  static const _walletAddressKey = 'mwa_wallet_address';
  static const _walletProviderKey = 'mwa_wallet_provider_id';
  static const _sessionTimestampKey = 'mwa_session_timestamp';
  static const _recentTransactionsCachePrefix = 'apto_recent_transactions_v1_';
  static const _recentTransactionsScanPrefix =
      'apto_recent_transactions_scan_v1_';
  static const Duration _recentTransactionsCacheDuration =
      Duration(seconds: 45);

  /// Keep session connected for 30 days without re-authenticating
  static const Duration sessionValidityPeriod = Duration(days: 30);

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _authToken;
  Future<void>? _balanceRequest;
  String? _balanceRequestAddress;
  DateTime? _balanceUpdatedAt;
  Future<List<WalletTransaction>>? _recentTransactionsRequest;
  String? _recentTransactionsRequestAddress;
  String? _recentTransactionsCacheAddress;
  DateTime? _recentTransactionsCachedAt;
  List<WalletTransaction>? _recentTransactionsCache;

  WalletProvider get activeWallet => activeWalletNotifier.value;
  String get currentPublicKey => fullAddressNotifier.value;
  bool get isConnected => isConnectedNotifier.value;

  RpcClient get _rpcClient => AptoBackendRpcClient.create();
  RpcClient get _devnetRpcClient => RpcClient(SolanaConfig.devnetRpcUrl);

  /// Restores saved wallet session if still within the 30-day validity window
  Future<bool> initialize() async {
    try {
      final savedAddress = await _secureStorage.read(key: _walletAddressKey);
      final timestampStr = await _secureStorage.read(key: _sessionTimestampKey);
      final providerId = await _secureStorage.read(key: _walletProviderKey);
      _authToken = await _secureStorage.read(key: _authTokenKey);

      if (savedAddress != null && savedAddress.isNotEmpty) {
        if (timestampStr != null) {
          final timestamp = int.tryParse(timestampStr) ?? 0;
          final ageMs = DateTime.now().millisecondsSinceEpoch - timestamp;
          if (ageMs > sessionValidityPeriod.inMilliseconds) {
            debugPrint('Saved wallet session expired (>30 days). Clearing...');
            disconnect();
            return false;
          }
        }

        final provider = WalletProvider.supportedWallets.firstWhere(
          (w) => w.id == providerId,
          orElse: () => WalletProvider.seedVault,
        );

        setWalletAddress(savedAddress, provider: provider, persist: false);
        debugPrint('Restored persistent wallet session: $savedAddress');
        return true;
      }
    } catch (e) {
      debugPrint('Error restoring wallet session: $e');
    }
    return false;
  }

  /// Selects a wallet provider and connects through Mobile Wallet Adapter.
  Future<bool> selectWallet(WalletProvider provider) async {
    activeWalletNotifier.value = provider;

    // A connect action must start a fresh wallet authorization. Persisted
    // tokens are only used later for transaction reauthorization.
    final authorization = await MwaSigningService.authorizeWallet(
      identityName: 'APTO Solana Pay via ${provider.name}',
    );
    if (authorization == null || authorization.publicKey.isEmpty) {
      return false;
    }

    _authToken = authorization.authToken;
    await _secureStorage.write(key: _authTokenKey, value: _authToken);
    final address = base58encode(authorization.publicKey);
    setWalletAddress(address, provider: provider, persist: true);
    await HceService.setReceiverAddress(address: address);
    await AptoAudioService.playInitialize();
    return true;
  }

  /// Sets the current active public key address, marks connected, and fetches live RPC balance
  void setWalletAddress(String address,
      {WalletProvider? provider, bool persist = true}) {
    if (provider != null) {
      activeWalletNotifier.value = provider;
    }
    fullAddressNotifier.value = address;
    if (address.length > 8) {
      walletAddressNotifier.value =
          '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
    } else {
      walletAddressNotifier.value = address;
    }
    isConnectedNotifier.value = address.isNotEmpty;
    HceService.setReceiverAddress(address: address);
    refreshBalance();
    FinancialInsightsService.instance.loadInsights();

    if (address.isNotEmpty) {
      unawaited(AptoFcmService.instance.registerWallet(address));
    } else {
      unawaited(AptoFcmService.instance.unregisterWallet());
    }

    if (persist && address.isNotEmpty) {
      _persistSession(address, activeWallet.id);
    }
  }

  Future<void> _persistSession(String address, String providerId) async {
    try {
      await _secureStorage.write(key: _walletAddressKey, value: address);
      await _secureStorage.write(
          key: 'apto_connected_wallet_address', value: address);
      await _secureStorage.write(key: _walletProviderKey, value: providerId);
      await _secureStorage.write(
        key: _sessionTimestampKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Also persist to SharedPreferences for background isolate accessibility
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('apto_connected_wallet_address', address);
      await prefs.setString(_walletAddressKey, address);
    } catch (e) {
      debugPrint('Failed to persist wallet session: $e');
    }
  }

  /// Disconnects active wallet
  void disconnect() {
    _secureStorage.delete(key: _authTokenKey);
    _secureStorage.delete(key: _walletAddressKey);
    _secureStorage.delete(key: 'apto_connected_wallet_address');
    _secureStorage.delete(key: _walletProviderKey);
    _secureStorage.delete(key: _sessionTimestampKey);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('apto_connected_wallet_address');
      prefs.remove(_walletAddressKey);
    }).catchError((_) {});
    _authToken = null;
    fullAddressNotifier.value = '';
    walletAddressNotifier.value = '';
    solBalanceNotifier.value = 0.0;
    usdcBalanceNotifier.value = 0.0;
    isConnectedNotifier.value = false;
    FinancialInsightsService.instance.insightsNotifier.value =
        FinancialInsights.empty();
    HceService.setReceiverAddress(address: '');
    unawaited(AptoFcmService.instance.unregisterWallet());
  }

  /// Queries real Solana Devnet RPC to fetch live SOL balance
  Future<void> refreshBalance() {
    final address = fullAddressNotifier.value;
    if (address.isEmpty) return Future<void>.value();

    if (_balanceRequest != null && _balanceRequestAddress == address) {
      return _balanceRequest!;
    }
    if (_balanceRequestAddress == address &&
        _balanceUpdatedAt != null &&
        DateTime.now().difference(_balanceUpdatedAt!) <
            const Duration(seconds: 15)) {
      return Future<void>.value();
    }

    _balanceRequestAddress = address;
    final request = _refreshBalance(address);
    _balanceRequest = request;
    return request.whenComplete(() {
      if (identical(_balanceRequest, request)) _balanceRequest = null;
    });
  }

  Future<void> _refreshBalance(String pubKeyStr) async {
    isBalanceLoadingNotifier.value = true;

    // 1. Instant cache load (0ms) so user sees previous balance immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBalance =
          prefs.getDouble('apto_cached_sol_balance_$pubKeyStr');
      if (cachedBalance != null &&
          fullAddressNotifier.value == pubKeyStr &&
          solBalanceNotifier.value == 0.0) {
        solBalanceNotifier.value = cachedBalance;
        usdcBalanceNotifier.value = cachedBalance * 180.0;
      }
    } catch (_) {}

    // 2. Fetch live balance with high-speed direct Devnet RPC first (~200ms)
    // to bypass Render backend cold-start delays (30s).
    double? liveSolVal;
    try {
      final directRpc = RpcClient(SolanaConfig.devnetRpcUrl);
      final result = await directRpc
          .getBalance(pubKeyStr)
          .timeout(const Duration(seconds: 4));
      liveSolVal = result.value / lamportsPerSol;
    } catch (directError) {
      debugPrint(
          'Direct Devnet RPC failed or timed out: $directError. Falling back to backend proxy...');
      // Fallback to backend proxy only if direct Devnet RPC fails
      try {
        final result = await AptoBackendRpcClient.run(
          () => _rpcClient.getBalance(pubKeyStr),
        ).timeout(const Duration(seconds: 12));
        liveSolVal = result.value / lamportsPerSol;
      } catch (backendError) {
        debugPrint('Backend balance proxy also failed: $backendError');
      }
    }

    try {
      if (liveSolVal != null && fullAddressNotifier.value == pubKeyStr) {
        solBalanceNotifier.value = liveSolVal;
        _balanceUpdatedAt = DateTime.now();
        usdcBalanceNotifier.value = liveSolVal * 180.0;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(
              'apto_cached_sol_balance_$pubKeyStr', liveSolVal);
        } catch (_) {}
      }
    } finally {
      isBalanceLoadingNotifier.value = false;
    }
  }

  final Map<String, WalletTransaction> _txDetailCache = {};

  Future<List<WalletTransaction>> fetchRecentTransactions({
    int limit = 10,
  }) {
    final address = fullAddressNotifier.value;
    if (address.isEmpty) return Future.value(const []);

    if (_recentTransactionsRequest != null &&
        _recentTransactionsRequestAddress == address) {
      return _recentTransactionsRequest!;
    }
    if (_recentTransactionsCacheAddress == address &&
        _recentTransactionsCache != null &&
        _recentTransactionsCachedAt != null &&
        DateTime.now().difference(_recentTransactionsCachedAt!) <
            _recentTransactionsCacheDuration) {
      return Future.value(_recentTransactionsCache);
    }

    _recentTransactionsRequestAddress = address;
    final request = _loadRecentTransactions(address, limit);
    _recentTransactionsRequest = request;
    return request.whenComplete(() {
      if (identical(_recentTransactionsRequest, request)) {
        _recentTransactionsRequest = null;
      }
    });
  }

  Future<List<WalletTransaction>> _loadRecentTransactions(
    String address,
    int limit,
  ) async {
    if (address.isEmpty) return const [];

    final localTransactions = await AptoTransactionStore.readAll();
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_recentTransactionsCachePrefix$address';
    final scanKey = '$_recentTransactionsScanPrefix$address';
    final lastScanEpoch = prefs.getInt(scanKey) ?? 0;
    List<WalletTransaction> cachedTransactions = [];

    try {
      final rawCache = prefs.getString(cacheKey);
      if (rawCache != null) {
        cachedTransactions = (jsonDecode(rawCache) as List<dynamic>)
            .map((value) => WalletTransaction.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error decoding cached recent transactions: $e');
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lastScanEpoch > 0 &&
        nowMs - lastScanEpoch <
            _recentTransactionsCacheDuration.inMilliseconds) {
      final results = _mergeRecentTransactions(
        cachedTransactions,
        localTransactions,
      );
      _cacheRecentTransactions(address, results);
      return results;
    }

    try {
      final signatures = await _devnetRpcClient
          .getSignaturesForAddress(address, limit: limit)
          .timeout(const Duration(seconds: 15));

      final List<WalletTransaction> results = [];

      for (var i = 0; i < signatures.length; i++) {
        final txInfo = signatures[i];
        final sig = txInfo.signature;

        if (_txDetailCache.containsKey(sig)) {
          results.add(_txDetailCache[sig]!);
          continue;
        }

        WalletTransaction? resolved;
        try {
          await Future.delayed(const Duration(milliseconds: 100));
          final details = await _devnetRpcClient
              .getTransaction(sig)
              .timeout(const Duration(seconds: 4));
          if (details != null && details.meta != null) {
            final pre = details.meta!.preBalances;
            final post = details.meta!.postBalances;
            final dynamic txObj = details.transaction;
            final dynamic msg = (txObj as dynamic).message;
            final dynamic accountKeys = msg?.accountKeys;

            int myIndex = -1;
            if (accountKeys is List) {
              for (var idx = 0; idx < accountKeys.length; idx++) {
                if (FinancialInsightsService.extractAccountPubkey(
                        accountKeys[idx]) ==
                    address) {
                  myIndex = idx;
                  break;
                }
              }
            }

            if (myIndex == -1 && details.meta!.loadedAddresses != null) {
              final loaded = details.meta!.loadedAddresses!;
              final loadedKeys = [...loaded.writable, ...loaded.readonly];
              for (var idx = 0; idx < loadedKeys.length; idx++) {
                if (loadedKeys[idx] == address) {
                  myIndex =
                      (accountKeys is List ? accountKeys.length : 0) + idx;
                  break;
                }
              }
            }

            if (myIndex >= 0 && myIndex < pre.length && myIndex < post.length) {
              final delta = post[myIndex] - pre[myIndex];
              final isSent = delta < 0;
              final isSuccessful =
                  details.meta!.err == null && txInfo.err == null;
              final fee = myIndex == 0 ? details.meta!.fee : 0;
              final amt = !isSuccessful
                  ? 0.0
                  : isSent
                      ? (delta.abs() - fee).clamp(0, double.infinity) /
                          lamportsPerSol
                      : (delta + (myIndex == 0 ? details.meta!.fee : 0)) /
                          lamportsPerSol;

              String otherParty = '';
              if (accountKeys is List && accountKeys.length > 1) {
                final otherIdx = isSent ? 1 : 0;
                if (otherIdx < accountKeys.length && otherIdx != myIndex) {
                  otherParty = FinancialInsightsService.extractAccountPubkey(
                    accountKeys[otherIdx],
                  );
                }
              }

              resolved = WalletTransaction(
                signature: sig,
                memo: txInfo.memo,
                blockTime: txInfo.blockTime ?? details.blockTime,
                isSuccessful: isSuccessful,
                amount: amt,
                type: isSent ? TransactionType.sent : TransactionType.received,
                counterparty: otherParty,
              );
            }
          }
        } catch (_) {}

        if (resolved != null) {
          _txDetailCache[sig] = resolved;
          results.add(resolved);
        }
      }

      final mergedResults =
          _mergeRecentTransactions(results, localTransactions);
      await prefs.setString(
        cacheKey,
        jsonEncode(mergedResults.map((tx) => tx.toJson()).toList()),
      );
      await prefs.setInt(scanKey, DateTime.now().millisecondsSinceEpoch);
      _cacheRecentTransactions(address, mergedResults);
      return mergedResults;
    } catch (e) {
      debugPrint('Error fetching recent transactions: $e');
      final fallback = _mergeRecentTransactions(
        cachedTransactions,
        localTransactions,
      );
      _cacheRecentTransactions(address, fallback);
      return fallback;
    }
  }

  List<WalletTransaction> _mergeRecentTransactions(
    List<WalletTransaction> transactions,
    List<WalletTransaction> localTransactions,
  ) {
    final merged = List<WalletTransaction>.from(transactions);
    for (final local in localTransactions) {
      if (!merged.any((tx) => tx.signature == local.signature)) {
        merged.insert(0, local);
      }
    }
    return merged;
  }

  void _cacheRecentTransactions(
    String address,
    List<WalletTransaction> transactions,
  ) {
    _recentTransactionsCacheAddress = address;
    _recentTransactionsCache = List.unmodifiable(transactions);
    _recentTransactionsCachedAt = DateTime.now();
  }

  Future<WalletTransactionDetails?> fetchTransactionDetails(
      String signature) async {
    final details = await AptoBackendRpcClient.run(
      () => _rpcClient.getTransaction(signature),
    );
    if (details == null) return null;

    return WalletTransactionDetails(
      signature: signature,
      slot: details.slot,
      blockTime: details.blockTime,
      feeLamports: details.meta?.fee,
      isSuccessful: details.meta?.err == null,
    );
  }

  /// Requests 1 SOL Devnet Airdrop directly from Solana RPC
  Future<bool> requestDevnetAirdrop() async {
    try {
      isBalanceLoadingNotifier.value = true;
      final pubKeyStr = fullAddressNotifier.value;

      final txSignature = await AptoBackendRpcClient.run(
        () => _rpcClient.requestAirdrop(
          pubKeyStr,
          lamportsPerSol,
        ),
      );

      debugPrint('Devnet Airdrop Requested! Signature: $txSignature');

      await AptoTransactionStore.record(
        WalletTransaction(
          signature: txSignature,
          memo: 'Devnet SOL Airdrop',
          blockTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          isSuccessful: true,
          amount: 1.0,
          type: TransactionType.received,
          counterparty: 'Devnet Faucet',
        ),
      );

      // Wait 2 seconds for block confirmation then refresh
      await Future.delayed(const Duration(seconds: 2));
      await refreshBalance();
      return true;
    } catch (e) {
      debugPrint('Devnet Airdrop Error: $e');
      return false;
    } finally {
      isBalanceLoadingNotifier.value = false;
    }
  }

  /// Signs transaction via MWA and submits to Solana RPC
  /// Automatically handles auth token refresh if the previous token was stale
  Future<List<int>?> signTransaction({
    required List<int> transactionBytes,
    required String identityName,
  }) async {
    final selected = activeWallet;
    lastTransactionSignatureNotifier.value = null;
    lastTransactionErrorNotifier.value = null;
    debugPrint('Initiating MWA signing with wallet provider: ${selected.name}');

    // Signal watchers that a send is happening — activates cooldown to prevent
    // false "received" notifications from stale RPC responses
    // Attempt MWA standard signing with current auth token
    List<int>? result;
    try {
      result = await MwaSigningService.signTransaction(
        unsignedTransactionBytes: transactionBytes,
        identityName: '$identityName via ${selected.name}',
        authToken: _authToken,
      );
    } catch (e) {
      debugPrint('MWA signTransaction outer error: $e');
      lastTransactionErrorNotifier.value = 'Seed Vault signing failed: $e';
      return null;
    }

    if (result == null) {
      debugPrint(
          'MWA signing returned null — user may have cancelled or auth expired.');
      return null;
    }

    // If signing succeeded, refresh the auth token for future operations
    // This ensures the next sign call uses a valid token
    _refreshAuthTokenInBackground(
        identityName: '$identityName via ${selected.name}');

    try {
      // Broadcast signed transaction to Solana Devnet RPC
      final txSig = await AptoBackendRpcClient.run(
        () => _rpcClient.sendTransaction(
          base64Encode(result!),
        ),
      );
      lastTransactionSignatureNotifier.value = txSig;
      debugPrint(
          'Transaction successfully broadcasted to Solana Devnet! Signature: $txSig');
    } catch (e) {
      lastTransactionErrorNotifier.value = e.toString();
      debugPrint('Solana RPC Broadcast error: $e');
    }
    return result;
  }

  /// Silently refreshes the auth token in the background so the next signing
  /// attempt uses a valid, fresh token and doesn't fail with stale reauthorize
  void _refreshAuthTokenInBackground({required String identityName}) {
    Future(() async {
      try {
        final auth = await MwaSigningService.authorizeWallet(
          identityName: identityName,
          authToken: null, // Fresh authorize to get a new token
        );
        if (auth != null && auth.authToken.isNotEmpty) {
          _authToken = auth.authToken;
          await _secureStorage.write(key: _authTokenKey, value: _authToken);
          debugPrint('Auth token refreshed successfully in background.');
        }
      } catch (e) {
        debugPrint('Background auth token refresh note: $e');
      }
    });
  }
}
