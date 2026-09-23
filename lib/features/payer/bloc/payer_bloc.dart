import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../solana_pay/models/solana_pay_request.dart';
// import '../../../core/security/anti_relay_checker.dart';
import '../../../core/security/attestation_service.dart';
import '../../../core/security/biometric_service.dart';
import '../../solana_pay/services/transaction_builder.dart';
import '../../wallet/services/wallet_adapter_service.dart';
import '../../wallet/domain/models/wallet_transaction.dart';
import '../../wallet/services/apto_transaction_store.dart';
import '../services/offline_intent_store.dart';

abstract class PayerEvent {}

class NfcTapPayloadReceivedEvent extends PayerEvent {
  final String rawApduString;
  final String payerPublicKey;
  NfcTapPayloadReceivedEvent(
      {required this.rawApduString, required this.payerPublicKey});
}

class ResetPayerEvent extends PayerEvent {}

class RetryPendingPaymentsEvent extends PayerEvent {}

abstract class PayerState {}

class PayerIdleState extends PayerState {}

class PayerVerifyingState extends PayerState {
  final String stepMessage;
  PayerVerifyingState(this.stepMessage);
}

class PayerSuccessState extends PayerState {
  final String txSignature;
  final double amount;
  final String recipient;
  PayerSuccessState({
    required this.txSignature,
    required this.amount,
    required this.recipient,
  });
}

class PayerFailureState extends PayerState {
  final String errorMessage;
  final bool isRelayAttackWarning;
  PayerFailureState(
      {required this.errorMessage, this.isRelayAttackWarning = false});
}

class PayerQueuedState extends PayerState {
  final int pendingCount;
  PayerQueuedState(this.pendingCount);
}

class PayerBloc extends Bloc<PayerEvent, PayerState> {
  PayerBloc() : super(PayerIdleState()) {
    on<NfcTapPayloadReceivedEvent>(_onPayloadReceived);
    on<RetryPendingPaymentsEvent>(_onRetryPendingPayments);
    on<ResetPayerEvent>((event, emit) => emit(PayerIdleState()));
  }

  Future<void> _onPayloadReceived(
    NfcTapPayloadReceivedEvent event,
    Emitter<PayerState> emit,
  ) async {
    SolanaPayRequest request;
    try {
      request = SolanaPayRequest.fromApduString(event.rawApduString);
    } catch (e) {
      emit(PayerFailureState(
          errorMessage: 'Invalid NFC Payload: ${e.toString()}'));
      return;
    }

    try {
      // 0. Verify connected wallet first
      if (event.payerPublicKey.isEmpty) {
        emit(PayerFailureState(
            errorMessage: 'Please connect your Solana wallet first before tapping to pay.'));
        return;
      }

      emit(PayerVerifyingState('Parsing Solana Pay NFC APDU...'));

      // 1. Hardware Enclave KeyAttestation Verification
      emit(PayerVerifyingState(
          'Verifying Android KeyAttestation TEE status...'));
      final attestation = await AttestationService.verifyHardwareEnclave();
      if (attestation['isSuccess'] == false) {
        emit(PayerFailureState(
          errorMessage:
              'Hardware Integrity Failure: Device TEE or KeyAttestation invalid.',
        ));
        return;
      }

      // 2. Biometric Authentication
      emit(PayerVerifyingState('Requesting Biometric Unlock...'));
      final biometricResult = await BiometricService.authenticate(
        reason: 'Authenticate to approve ${request.amount} SOL tap transfer',
      );
      if (!biometricResult.isAuthenticated) {
        emit(PayerFailureState(
            errorMessage: biometricResult.failureReason ??
                'Biometric unlock cancelled or failed.'));
        return;
      }

      await _submitRequest(request, event.payerPublicKey, emit);
    } catch (e) {
      emit(PayerFailureState(
          errorMessage: 'Payment error: ${e.toString()}'));
    }
  }

  Future<void> _submitRequest(
    SolanaPayRequest request,
    String payerPublicKey,
    Emitter<PayerState> emit,
  ) async {
    try {
      emit(PayerVerifyingState('Building Solana transfer...'));
      final unsignedTransaction =
          await TransactionBuilder.buildUnsignedTransaction(
        payerPublicKey: payerPublicKey,
        request: request,
      );

      emit(PayerVerifyingState('Approve the transfer in Seed Vault...'));
      final signedTransaction =
          await WalletAdapterService.instance.signTransaction(
        transactionBytes: unsignedTransaction,
        identityName: 'APTO NFC Tap-to-Pay',
      );

      if (signedTransaction == null) {
        emit(PayerFailureState(
            errorMessage: 'Seed Vault signing was cancelled or unavailable.'));
        return;
      }

      final transactionSignature =
          WalletAdapterService.instance.lastTransactionSignatureNotifier.value;
      if (transactionSignature == null) {
        final broadcastError =
            WalletAdapterService.instance.lastTransactionErrorNotifier.value;
        emit(PayerFailureState(
            errorMessage: broadcastError == null
                ? 'The signed transfer was not submitted.'
                : 'The signed transfer was rejected by Devnet: $broadcastError'));
        return;
      }

      await AptoTransactionStore.record(
        WalletTransaction(
          signature: transactionSignature,
          memo: request.message.isNotEmpty ? request.message : 'NFC Tap-to-Pay',
          blockTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          isSuccessful: true,
          amount: request.amount,
          type: TransactionType.sent,
          counterparty: request.recipient,
        ),
      );

      emit(PayerSuccessState(
        txSignature: transactionSignature,
        amount: request.amount,
        recipient: request.recipient,
      ));
    } catch (e, stackTrace) {
      debugPrint('Payment processing error: $e\n$stackTrace');
      try {
        await OfflineIntentStore.add(OfflinePaymentIntent(
          request: request,
          payerPublicKey: payerPublicKey,
        ));
        final pending = await OfflineIntentStore.readAll();
        emit(PayerQueuedState(pending.length));
      } catch (storeError) {
        debugPrint('OfflineIntentStore error: $storeError');
        emit(PayerFailureState(
            errorMessage: 'Payment submission failed: ${e.toString()}'));
      }
    }
  }

  Future<void> _onRetryPendingPayments(
    RetryPendingPaymentsEvent event,
    Emitter<PayerState> emit,
  ) async {
    final pending = await OfflineIntentStore.readAll();
    if (pending.isEmpty) {
      emit(PayerIdleState());
      return;
    }

    final intent = pending.first;
    await _submitRequest(intent.request, intent.payerPublicKey, emit);
    if (state is PayerSuccessState) {
      await OfflineIntentStore.remove(intent);
    }
  }
}
