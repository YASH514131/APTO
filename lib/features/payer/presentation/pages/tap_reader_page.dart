import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/nfc_video_animation_widget.dart';
import '../../bloc/payer_bloc.dart';
import '../../services/nfc_reader_service.dart';
import '../../../solana_pay/models/solana_pay_request.dart';
import '../../../wallet/services/wallet_adapter_service.dart';
import 'package:solana/solana.dart';
import '../../../wallet/presentation/widgets/wallet_selector_sheet.dart';
import '../../../rewards/presentation/dialogs/skr_scratch_reward_dialog.dart';

class TapReaderPage extends StatefulWidget {
  const TapReaderPage({super.key});

  @override
  State<TapReaderPage> createState() => _TapReaderPageState();
}

class _TapReaderPageState extends State<TapReaderPage>
    with TickerProviderStateMixin {
  bool _isScanning = false;
  bool _showHintHand = false;
  late AnimationController _handAnimController;
  late Animation<double> _handBobAnimation;
  late Animation<double> _handOpacity;
  late AnimationController _pulseAnimController;

  // Text slide-down animation (syncs with card reveal)
  late AnimationController _textSlideController;
  late Animation<double> _textSlideAnimation;

  @override
  void initState() {
    super.initState();
    _handAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _handBobAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _handAnimController, curve: Curves.easeInOut),
    );
    _handOpacity = Tween<double>(begin: 0.0, end: 0.7).animate(
      CurvedAnimation(
        parent: _handAnimController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Text slides down when card reveals
    _textSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _textSlideAnimation = CurvedAnimation(
      parent: _textSlideController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Show hint hand after 3 seconds if user hasn't tapped
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isScanning) {
        setState(() => _showHintHand = true);
        _handAnimController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _handAnimController.dispose();
    _pulseAnimController.dispose();
    _textSlideController.dispose();
    super.dispose();
  }

  Future<void> _toggleNfcScan(BuildContext context) async {
    if (_isScanning) {
      await _stopNfcScan();
      return;
    }

    final isConnected = WalletAdapterService.instance.isConnected;
    final payerPublicKey = WalletAdapterService.instance.currentPublicKey;
    if (!isConnected || payerPublicKey.isEmpty) {
      WalletSelectorSheet.show(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Connect your Solana wallet first to enable tap & pay',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: AppTheme.cardBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF4FA8B7), width: 1),
          ),
        ),
      );
      return;
    }

    await _startNfcScan(context);
  }

  Future<void> _stopNfcScan() async {
    await NfcReaderService.stop();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _showHintHand = true;
      });
      _pulseAnimController.stop();
      _pulseAnimController.reset();
      _handAnimController.repeat(reverse: true);
      _textSlideController.reverse();
    }
  }

  Future<void> _startNfcScan(BuildContext context) async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _showHintHand = false;
    });
    _handAnimController.stop();
    _pulseAnimController.repeat(reverse: true);
    _textSlideController.forward();

    final payerBloc = context.read<PayerBloc>();
    final payerPublicKey = WalletAdapterService.instance.currentPublicKey;
    await NfcReaderService.scan(
      onPayload: (payload) async {
        if (!mounted) return;
        await NfcReaderService.stop();
        if (!mounted) return;
        var payloadToProcess = payload;
        final request = SolanaPayRequest.fromApduString(payload);
        if (request.isAddressOnly) {
          // The NFC callback is owned by this mounted State.
          // ignore: use_build_context_synchronously
          final amount = await _requestRepaymentAmount(context);
          if (!mounted || amount == null) {
            if (mounted) {
              setState(() => _isScanning = false);
              _pulseAnimController.stop();
              _pulseAnimController.reset();
              _textSlideController.reverse();
            }
            return;
          }
          final ephemeralRef = (await Ed25519HDKeyPair.random()).address;
          final updatedRequest = request.withAmount(
            amount,
            reference: ephemeralRef,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          payloadToProcess =
              '${updatedRequest.toSolanaPayUrl()}|${updatedRequest.timestampMs}';
        }
        payerBloc.add(
          NfcTapPayloadReceivedEvent(
            rawApduString: payloadToProcess,
            payerPublicKey: payerPublicKey,
          ),
        );
        setState(() => _isScanning = false);
        _pulseAnimController.stop();
        _pulseAnimController.reset();
        _textSlideController.reverse();
      },
      onError: (message) async {
        debugPrint('NFC scan session notice: $message');
        // Do not abruptly collapse the visual card animation if NFC hardware is temporarily
        // unavailable or times out. The user can tap to close whenever they want.
      },
    );
  }

  Future<double?> _requestRepaymentAmount(BuildContext context) async {
    return showDialog<double>(
      context: context,
      builder: (_) => const _RepaymentAmountDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PayerBloc(),
      child: Scaffold(
        backgroundColor: const Color(0xFF031016),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'lib/assets/images/logo.jpg',
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Tap & Pay',
                style: AppTheme.serifHeading(
                    fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'lib/assets/images/taptopay.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF031016),
                ),
              ),
            ),
            BlocConsumer<PayerBloc, PayerState>(
              listener: (context, state) {
                if (state is PayerSuccessState) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      final amountUsd =
                          state.amount > 0 ? (state.amount * 150.0) : 20.0;
                      SkrScratchRewardDialog.show(
                        context,
                        txSig: state.txSignature,
                        amountUsd: amountUsd,
                      );
                    }
                  });
                } else if (state is PayerFailureState) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ ${state.errorMessage}'),
                      backgroundColor: state.isRelayAttackWarning
                          ? Colors.deepOrange
                          : Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else if (state is PayerQueuedState) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Payment saved offline (${state.pendingCount} pending)'),
                      backgroundColor: AppTheme.seedVaultTeal,
                    ),
                  );
                }
              },
              builder: (context, state) {
                final mediaQuery = MediaQuery.of(context);
                final screenHeight = mediaQuery.size.height;
                final screenWidth = mediaQuery.size.width;
                final isSmallWidth = screenWidth < 360;
                final isShortHeight = screenHeight < 700;
                final double horizontalPadding = isSmallWidth ? 16.0 : 20.0;
                final double topPadding = isShortHeight ? 12.0 : 20.0;
                final double bottomPadding =
                    mediaQuery.padding.bottom + (isShortHeight ? 80.0 : 100.0);
                final double spacingBetweenCardAndText =
                    isShortHeight ? 18.0 : 28.0;
                final double textSlideDistance = isShortHeight ? 18.0 : 28.0;

                return SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: horizontalPadding,
                              right: horizontalPadding,
                              top: topPadding,
                              bottom: bottomPadding,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 420),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // NFC Video Animation Target with ghost hand hint & glowing pulse aura
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AnimatedBuilder(
                                          animation: _pulseAnimController,
                                          builder: (context, child) {
                                            final glow = _isScanning
                                                ? _pulseAnimController.value
                                                : 0.0;
                                            return Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(26),
                                                boxShadow: _isScanning
                                                    ? [
                                                        BoxShadow(
                                                          color: AppTheme
                                                              .seedVaultTeal
                                                              .withValues(
                                                                  alpha: 0.18 +
                                                                      (glow *
                                                                          0.28)),
                                                          blurRadius:
                                                              24 + (glow * 16),
                                                          spreadRadius:
                                                              2 + (glow * 4),
                                                        ),
                                                      ]
                                                    : [],
                                              ),
                                              child: child,
                                            );
                                          },
                                          child: NfcVideoAnimationWidget(
                                            videoPath:
                                                'lib/assets/vedio/nfc_wave.mp4',
                                            isRevealed: _isScanning,
                                            onTap: () =>
                                                _toggleNfcScan(context),
                                          ),
                                        ),
                                        // Ghost hand hint
                                        if (_showHintHand)
                                          Positioned(
                                            bottom: -10,
                                            right: 16,
                                            child: AnimatedBuilder(
                                              animation: _handAnimController,
                                              builder: (context, child) {
                                                return Transform.translate(
                                                  offset: Offset(0,
                                                      -_handBobAnimation.value),
                                                  child: Opacity(
                                                    opacity: _handOpacity.value,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child: const Icon(
                                                Icons.touch_app_rounded,
                                                size: 44,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    SizedBox(height: spacingBetweenCardAndText),

                                    // Bottom status container — slides down smoothly when card reveals
                                    AnimatedBuilder(
                                      animation: _textSlideAnimation,
                                      builder: (context, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                              0,
                                              _textSlideAnimation.value *
                                                  textSlideDistance),
                                          child: child,
                                        );
                                      },
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: _buildStatusContent(
                                            context, state, isSmallWidth),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(
      BuildContext context, PayerState state, bool isSmallWidth) {
    if (state is PayerVerifyingState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF4FA8B7)),
          const SizedBox(height: 12),
          Text(
            state.stepMessage,
            style:
                AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      );
    }

    if (state is PayerQueuedState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${state.pendingCount} payment pending',
            style: AppTheme.serifHeading(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                context.read<PayerBloc>().add(RetryPendingPaymentsEvent()),
            child: const Text('Retry when online'),
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.15),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _isScanning
          ? GestureDetector(
              key: const ValueKey('scanning_view'),
              onTap: () => _toggleNfcScan(context),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseAnimController.value * 0.12),
                            child: const Icon(
                              Icons.nfc_rounded,
                              color: AppTheme.seedVaultTeal,
                              size: 24,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Hold your phone to terminal',
                          textAlign: TextAlign.center,
                          style: AppTheme.serifHeading(
                            fontSize: isSmallWidth ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Align back of device near the terminal reader',
                      textAlign: TextAlign.center,
                      style: AppTheme.sansBody(
                        fontSize: isSmallWidth ? 12 : 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.seedVaultTeal.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to cancel',
                          style: AppTheme.sansBody(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : ValueListenableBuilder<bool>(
              valueListenable:
                  WalletAdapterService.instance.isConnectedNotifier,
              builder: (context, isConnected, _) {
                return GestureDetector(
                  key: const ValueKey('idle_view'),
                  onTap: () => _toggleNfcScan(context),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                const Color(0xFF4FA8B7).withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4FA8B7)
                                  .withValues(alpha: 0.12),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isConnected
                                  ? Icons.touch_app_rounded
                                  : Icons.link_rounded,
                              color: const Color(0xFF4FA8B7),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isConnected
                                  ? 'Tap to pay'
                                  : 'Connect wallet to pay',
                              style: AppTheme.serifHeading(
                                fontSize: isSmallWidth ? 17 : 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          isConnected
                              ? 'Hardware KeyAttestation & Micro-timestamp anti-relay active.'
                              : 'Connect your Seed Vault or Solana wallet to activate instant tap-to-pay.',
                          textAlign: TextAlign.center,
                          style: AppTheme.sansBody(
                            fontSize: isSmallWidth ? 12 : 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _RepaymentAmountDialog extends StatefulWidget {
  const _RepaymentAmountDialog();

  @override
  State<_RepaymentAmountDialog> createState() => _RepaymentAmountDialogState();
}

class _RepaymentAmountDialogState extends State<_RepaymentAmountDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Please enter an amount');
      return;
    }
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      setState(() => _errorText = 'Enter a valid amount greater than 0');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.outlineBorder, width: 1.2),
      ),
      title: Text(
        'Enter payment amount',
        style: AppTheme.serifHeading(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specify the SOL amount to transfer to the merchant.',
            style:
                AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTheme.sansBody(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: AppTheme.sansBody(
                fontSize: 16,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
              suffixText: 'SOL',
              suffixStyle: AppTheme.sansBody(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4FA8B7),
              ),
              errorText: _errorText,
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.outlineBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF4FA8B7), width: 1.5),
              ),
            ),
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTheme.sansBody(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4FA8B7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text('Continue',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
