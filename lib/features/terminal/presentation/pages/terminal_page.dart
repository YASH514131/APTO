import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animation/animated_pressable.dart';
import '../../../../core/animation/staggered_entrance.dart';
import '../../bloc/terminal_bloc.dart';
import '../../../wallet/services/wallet_adapter_service.dart';
import '../../../../shared/widgets/transaction_success_dialog.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  String _amount = "0.1";

  final Map<String, String> _subText = const {
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '.': '',
    '0': '+',
  };

  void _onKeyPress(String value) {
    setState(() {
      if (_amount == "0" || _amount == "0.0") {
        _amount = value;
      } else {
        _amount += value;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = "0";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TerminalBloc(),
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
                'Merchant Terminal',
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
                'lib/assets/images/merchant.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF031016),
                ),
              ),
            ),
            BlocConsumer<TerminalBloc, TerminalState>(
              listener: (context, state) {
                if (state is TerminalPaymentConfirmedState) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      TransactionSuccessDialog.show(
                        context,
                        signature: state.signature,
                        title: 'Payment received',
                      );
                    }
                  });
                }
              },
              builder: (context, state) {
                final isBroadcasting = state is TerminalBroadcastingState;

                return SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        left: 24.0, right: 24.0, top: 12.0,
                        bottom: MediaQuery.of(context).padding.bottom + 100),
                    child: Column(
                  children: [
                    // Amount Card with smooth neon glow transition
                    StaggeredEntrance(
                      index: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isBroadcasting
                                ? AppTheme.seedVaultTeal
                                : Colors.white.withValues(alpha: 0.06),
                            width: 1.5,
                          ),
                          boxShadow: isBroadcasting
                              ? [
                                  BoxShadow(
                                    color: AppTheme.seedVaultTeal
                                        .withValues(alpha: 0.25),
                                    blurRadius: 22,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                isBroadcasting
                                    ? 'ACTIVE HCE NFC BROADCAST'
                                    : 'ENTER CHARGE AMOUNT',
                                key: ValueKey<bool>(isBroadcasting),
                                style: AppTheme.sansBody(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isBroadcasting
                                      ? AppTheme.seedVaultTeal
                                      : AppTheme.textSecondary,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _amount,
                                    style: AppTheme.serifHeading(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SOL',
                                    style: AppTheme.sansBody(
                                        fontSize: 18,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Apple-style Fluid Animated Switcher between Dial Pad & Broadcasting Radar
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 460),
                      switchInCurve: Curves.easeOutQuart,
                      switchOutCurve: Curves.easeInQuart,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final isBroadcastingView =
                            child.key == const ValueKey('broadcasting_view');
                        final offsetTween = isBroadcastingView
                            ? Tween<Offset>(
                                begin: const Offset(0.0, 0.12),
                                end: Offset.zero,
                              )
                            : Tween<Offset>(
                                begin: const Offset(0.0, -0.12),
                                end: Offset.zero,
                              );

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetTween.animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: isBroadcasting
                          ? _buildBroadcastingView()
                          : _buildDialPadView(),
                    ),

                    const SizedBox(height: 20),

                    // Action Button with Apple-style Fluid Morph & Color Transition
                    StaggeredEntrance(
                      index: 2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isBroadcasting
                              ? const Color(0xFFE53935)
                              : AppTheme.seedVaultTeal,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (isBroadcasting
                                      ? const Color(0xFFE53935)
                                      : AppTheme.seedVaultTeal)
                                  .withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AnimatedPressable(
                          onTap: () {
                            final bloc = context.read<TerminalBloc>();
                            if (isBroadcasting) {
                              bloc.add(StopTerminalBroadcastEvent());
                            } else {
                              final amt = double.tryParse(_amount) ?? 0.0;
                              final recipient = WalletAdapterService
                                  .instance.currentPublicKey;
                              if (amt > 0 && recipient.isNotEmpty) {
                                bloc.add(StartTerminalBroadcastEvent(
                                  amount: amt,
                                  recipientPubkey: recipient,
                                ));
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.25),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Row(
                                key: ValueKey<bool>(isBroadcasting),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isBroadcasting
                                        ? Icons.close_rounded
                                        : Icons.nfc_rounded,
                                    color: AppTheme.textPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isBroadcasting
                                        ? 'Cancel HCE Broadcast'
                                        : 'Start NFC Tap Broadcast',
                                    style: AppTheme.sansBody(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  ),
);
  }

  Widget _buildBroadcastingView() {
    return Container(
      key: const ValueKey('broadcasting_view'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 280),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.seedVaultTeal.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seedVaultTeal.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sleek clean NFC Badge (static, no breathing effect)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.seedVaultTeal.withValues(alpha: 0.15),
              border: Border.all(
                color: AppTheme.seedVaultTeal.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.seedVaultTeal.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.nfc_rounded,
              color: AppTheme.seedVaultTeal,
              size: 34,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready for Tap',
            style: AppTheme.serifHeading(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hold payer device against the back of this phone to accept SOL',
            textAlign: TextAlign.center,
            style: AppTheme.sansBody(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialPadView() {
    return Container(
      key: const ValueKey('dial_pad_view'),
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 280),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.15,
        crossAxisSpacing: 16,
        mainAxisSpacing: 14,
        children: [
          ...[
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '.',
            '0'
          ].map(
            (val) => _buildDialButton(
              value: val,
              subtext: _subText[val] ?? '',
              onTap: () => _onKeyPress(val),
            ),
          ),
          _buildDialButton(
            icon: Icons.backspace_outlined,
            onTap: _onBackspace,
          ),
        ],
      ),
    );
  }

  Widget _buildDialButton({
    String? value,
    String subtext = '',
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return AnimatedPressable(
      onTap: onTap,
      scaleFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardBg,
          border: Border.all(color: AppTheme.outlineBorder, width: 1.2),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: AppTheme.textSecondary, size: 22)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value!,
                      style: AppTheme.sansBody(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtext.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtext,
                        style: AppTheme.sansBody(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
