import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';
import '../models/solana_pay_request.dart';
import '../../../core/constants/solana_config.dart';

class TransactionBuilder {
  /// Assembles an unsigned Solana Pay transaction with payment transfer + reference key
  static Future<List<int>> buildUnsignedTransaction({
    required String payerPublicKey,
    required SolanaPayRequest request,
  }) async {
    final client = SolanaClient(
      rpcUrl: Uri.parse(SolanaConfig.activeRpcUrl),
      websocketUrl:
          Uri.parse(SolanaConfig.activeRpcUrl.replaceAll('https', 'wss')),
    );

    final recentBlockhash = await client.rpcClient.getLatestBlockhash();

    final payerPubKey = Ed25519HDPublicKey.fromBase58(payerPublicKey);
    final recipientPubKey = Ed25519HDPublicKey.fromBase58(request.recipient);
    final lamports = (request.amount * lamportsPerSol).toInt();

    final accounts = <AccountMeta>[
      AccountMeta.writeable(pubKey: payerPubKey, isSigner: true),
      AccountMeta.writeable(pubKey: recipientPubKey, isSigner: false),
    ];

    // Include the Solana Pay reference as an extra readonly account on the
    // transfer if provided. It remains discoverable by reference polling
    // without making the reference key a required signer.
    if (request.reference.trim().isNotEmpty) {
      try {
        final referencePubKey =
            Ed25519HDPublicKey.fromBase58(request.reference.trim());
        accounts.add(AccountMeta.readonly(pubKey: referencePubKey, isSigner: false));
      } catch (_) {
        // If reference is not a valid base58 pubkey, continue with standard transfer
      }
    }

    final transferInstruction = Instruction(
      programId: SystemProgram.id,
      accounts: accounts,
      data: ByteArray.merge([
        SystemProgram.transferInstructionIndex,
        ByteArray.u64(lamports),
      ]),
    );

    final message = Message(
      instructions: [
        transferInstruction,
      ],
    );

    final compiledMessage = message.compile(
      recentBlockhash: recentBlockhash.value.blockhash,
      feePayer: payerPubKey,
    );

    // MWA expects a complete serialized transaction, including one placeholder
    // signature for each required signer. The wallet replaces this zeroed
    // fee-payer signature with the Seed Vault signature.
    final unsignedTransaction = SignedTx(
      signatures: [
        Signature(List.filled(64, 0), publicKey: payerPubKey),
      ],
      compiledMessage: compiledMessage,
    );

    return unsignedTransaction.toByteArray().toList();
  }
}
