import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solana/solana.dart';
import '../services/hce_service.dart';
import '../../solana_pay/models/solana_pay_request.dart';
import '../../solana_pay/services/reference_poller.dart';
import '../../wallet/domain/models/wallet_transaction.dart';
import '../../wallet/services/apto_transaction_store.dart';

abstract class TerminalEvent {}

class StartTerminalBroadcastEvent extends TerminalEvent {
  final double amount;
  final String recipientPubkey;
  StartTerminalBroadcastEvent({required this.amount, required this.recipientPubkey});
}

class StopTerminalBroadcastEvent extends TerminalEvent {}

abstract class TerminalState {}

class TerminalIdleState extends TerminalState {}

class TerminalBroadcastingState extends TerminalState {
  final SolanaPayRequest request;
  TerminalBroadcastingState(this.request);
}

class TerminalPaymentConfirmedState extends TerminalState {
  final String signature;
  final double amount;
  TerminalPaymentConfirmedState({required this.signature, required this.amount});
}

class TerminalErrorState extends TerminalState {
  final String message;
  TerminalErrorState(this.message);
}

class TerminalBloc extends Bloc<TerminalEvent, TerminalState> {
  final ReferencePoller _poller = ReferencePoller();

  TerminalBloc() : super(TerminalIdleState()) {
    on<StartTerminalBroadcastEvent>(_onStartBroadcast);
    on<StopTerminalBroadcastEvent>(_onStopBroadcast);
  }

  Future<void> _onStartBroadcast(
    StartTerminalBroadcastEvent event,
    Emitter<TerminalState> emit,
  ) async {
    try {
      // Generate ephemeral single-use reference keypair
      final refKeypair = await Ed25519HDKeyPair.random();
      final reference = refKeypair.address;

      final request = SolanaPayRequest(
        recipient: event.recipientPubkey,
        amount: event.amount,
        reference: reference,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

      final success = await HceService.setTerminalPayload(
        payload: request.toSolanaPayUrl(),
        reference: reference,
      );

      if (!success) {
        emit(TerminalErrorState('Failed to initialize Android HCE service'));
        return;
      }

      emit(TerminalBroadcastingState(request));

      // Start asynchronous RPC confirmation polling
      final signature = await _poller.pollForConfirmation(referencePublicKey: reference);

      if (signature != null) {
        await HceService.stopTerminalBroadcast();
        await AptoTransactionStore.record(
          WalletTransaction(
            signature: signature,
            memo: 'Merchant Payment Received',
            blockTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            isSuccessful: true,
            amount: event.amount,
            type: TransactionType.received,
            counterparty: 'Terminal Customer',
          ),
        );
        emit(TerminalPaymentConfirmedState(signature: signature, amount: event.amount));
      }
    } catch (e) {
      emit(TerminalErrorState(e.toString()));
    }
  }

  Future<void> _onStopBroadcast(
    StopTerminalBroadcastEvent event,
    Emitter<TerminalState> emit,
  ) async {
    await HceService.stopTerminalBroadcast();
    emit(TerminalIdleState());
  }
}
