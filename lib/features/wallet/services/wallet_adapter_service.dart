import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';
import 'package:solana/base58.dart';
import '../domain/models/wallet_provider.dart';
import '../domain/models/wallet_transaction.dart';
import '../domain/models/wallet_transaction_details.dart';
import '../../solana_pay/services/mwa_signing_service.dart';
import '../../terminal/services/hce_service.dart';
import '../../../core/constants/solana_config.dart';
import '../../../core/services/apto_audio_service.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _authToken;

  WalletProvider get activeWallet => activeWalletNotifier.value;
  String get currentPublicKey => fullAddressNotifier.value;
  bool get isConnected => isConnectedNotifier.value;

  final SolanaClient _solanaClient = SolanaClient(
    rpcUrl: Uri.parse(SolanaConfig.activeRpcUrl),
    websocketUrl:
        Uri.parse(SolanaConfig.activeRpcUrl.replaceAll('https', 'wss')),
  );

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
    setWalletAddress(address);
    await HceService.setReceiverAddress(address: address);
    await AptoAudioService.playInitialize();
    return true;
  }

  /// Sets the current active public key address, marks connected, and fetches live RPC balance
  void setWalletAddress(String address) {
    fullAddressNotifier.value = address;
    if (address.length > 8) {
      walletAddressNotifier.value =
          '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
    } else {
      walletAddressNotifier.value = address;
    }
    isConnectedNotifier.value = true;
    HceService.setReceiverAddress(address: address);
    refreshBalance();
  }

  /// Disconnects active wallet
  void disconnect() {
    _secureStorage.delete(key: _authTokenKey);
    _authToken = null;
    fullAddressNotifier.value = '';
    walletAddressNotifier.value = '';
    solBalanceNotifier.value = 0.0;
    usdcBalanceNotifier.value = 0.0;
    isConnectedNotifier.value = false;
  }

  /// Queries real Solana Devnet RPC to fetch live SOL balance
  Future<void> refreshBalance() async {
    try {
      isBalanceLoadingNotifier.value = true;
      final pubKeyStr = fullAddressNotifier.value;

      // Query RPC for account info
      final result = await _solanaClient.rpcClient.getBalance(pubKeyStr);
      final solVal = result.value / lamportsPerSol;

      solBalanceNotifier.value = solVal;
      // Derive USDC equivalent display (e.g. 1 SOL = ~180 USDC simulated rate for Devnet)
      usdcBalanceNotifier.value = solVal * 180.0;
    } catch (e) {
      debugPrint(
          'RPC Balance Fetch Note (Address may be unfunded on Devnet): $e');
      // Keep present balance state if unfunded new address
    } finally {
      isBalanceLoadingNotifier.value = false;
    }
  }

  Future<List<WalletTransaction>> fetchRecentTransactions({
    int limit = 10,
  }) async {
    final address = fullAddressNotifier.value;
    if (address.isEmpty) return const [];

    final signatures = await _solanaClient.rpcClient.getSignaturesForAddress(
      address,
      limit: limit,
    );

    return signatures
        .map(
          (transaction) => WalletTransaction(
            signature: transaction.signature,
            memo: transaction.memo,
            blockTime: transaction.blockTime,
            isSuccessful: transaction.err == null,
          ),
        )
        .toList();
  }

  Future<WalletTransactionDetails?> fetchTransactionDetails(
      String signature) async {
    final details = await _solanaClient.rpcClient.getTransaction(signature);
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

      final txSignature = await _solanaClient.rpcClient.requestAirdrop(
        pubKeyStr,
        lamportsPerSol,
      );

      debugPrint('Devnet Airdrop Requested! Signature: $txSignature');

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
  Future<List<int>?> signTransaction({
    required List<int> transactionBytes,
    required String identityName,
  }) async {
    final selected = activeWallet;
    lastTransactionSignatureNotifier.value = null;
    lastTransactionErrorNotifier.value = null;
    debugPrint('Initiating MWA signing with wallet provider: ${selected.name}');

    // Attempt MWA standard signing
    final result = await MwaSigningService.signTransaction(
      unsignedTransactionBytes: transactionBytes,
      identityName: '$identityName via ${selected.name}',
      authToken: _authToken,
    );

    if (result != null) {
      try {
        // Broadcast signed transaction to Solana Devnet RPC
        final txSig = await _solanaClient.rpcClient.sendTransaction(
          base64Encode(result),
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

    return null;
  }
}
