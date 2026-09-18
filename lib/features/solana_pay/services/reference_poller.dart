import 'dart:async';
import 'package:solana/solana.dart';
import '../../../core/constants/solana_config.dart';

class ReferencePoller {
  final SolanaClient _client = SolanaClient(
    rpcUrl: Uri.parse(SolanaConfig.activeRpcUrl),
    websocketUrl: Uri.parse(SolanaConfig.activeRpcUrl.replaceAll('https', 'wss')),
  );

  /// Polls Solana RPC for a transaction referencing [referencePublicKey]
  Future<String?> pollForConfirmation({
    required String referencePublicKey,
    Duration pollInterval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final signatures = await _client.rpcClient.getSignaturesForAddress(
          referencePublicKey,
          limit: 1,
        );

        if (signatures.isNotEmpty) {
          final txSignature = signatures.first.signature;
          return txSignature;
        }
      } catch (e) {
        // Continue polling until timeout
      }

      attempts++;
      await Future.delayed(pollInterval);
    }
    return null;
  }
}
