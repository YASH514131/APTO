import 'dart:async';
import 'package:solana/solana.dart';
import '../../../core/services/apto_backend_rpc_client.dart';

class ReferencePoller {
  final RpcClient _client = AptoBackendRpcClient.create();

  /// Polls Solana RPC for a transaction referencing [referencePublicKey]
  Future<String?> pollForConfirmation({
    required String referencePublicKey,
    Duration pollInterval = const Duration(seconds: 5),
    int maxAttempts = 12,
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final signatures = await AptoBackendRpcClient.run(
          () => _client.getSignaturesForAddress(
            referencePublicKey,
            limit: 1,
          ),
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
