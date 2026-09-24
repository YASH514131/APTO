import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animation/animated_pressable.dart';
import '../../../../core/animation/staggered_entrance.dart';
import '../../../wallet/domain/models/wallet_provider.dart';
import '../../../wallet/services/wallet_adapter_service.dart';
import '../../../wallet/presentation/widgets/wallet_selector_sheet.dart';

class ConfirmPaymentScreen extends StatelessWidget {
  final String recipient;
  final String amountUsdc;

  const ConfirmPaymentScreen({
    super.key,
    this.recipient = '7xKX...9fQ2',
    this.amountUsdc = '12.50',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              StaggeredEntrance(
                index: 0,
                child: Text(
                  'Confirm payment',
                  style: AppTheme.serifHeading(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 24),

              // Payment Confirmation Details Card
              StaggeredEntrance(
                index: 1,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To',
                        style: AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipient,
                        style: AppTheme.serifHeading(fontSize: 18, fontWeight: FontWeight.w600),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: AppTheme.outlineBorder, height: 1),
                      ),

                      Text(
                        'Amount',
                        style: AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            amountUsdc,
                            style: AppTheme.serifHeading(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'USDC',
                            style: AppTheme.sansBody(fontSize: 16, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: AppTheme.outlineBorder, height: 1),
                      ),

                      // Selected Wallet Provider Detail
                      ValueListenableBuilder<WalletProvider>(
                        valueListenable: WalletAdapterService.instance.activeWalletNotifier,
                        builder: (context, activeWallet, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Signing Wallet',
                                    style: AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(activeWallet.icon, color: activeWallet.color, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        activeWallet.name,
                                        style: AppTheme.sansBody(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => WalletSelectorSheet.show(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Change',
                                  style: AppTheme.sansBody(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.seedVaultTeal),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: AppTheme.outlineBorder, height: 1),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Security Attestation',
                            style: AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: AppTheme.solanaGreen, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Hardware Verified',
                                style: AppTheme.sansBody(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.solanaGreen),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Network fee',
                            style: AppTheme.sansBody(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          Text(
                            '0.00025 SOL',
                            style: AppTheme.sansBody(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Primary Action: Sign with Active Wallet
              ValueListenableBuilder<WalletProvider>(
                valueListenable: WalletAdapterService.instance.activeWalletNotifier,
                builder: (context, activeWallet, child) {
                  return StaggeredEntrance(
                    index: 2,
                    child: SizedBox(
                      width: double.infinity,
                      child: AnimatedPressable(
                        onTap: () async {
                          final signedBytes = await WalletAdapterService.instance.signTransaction(
                            transactionBytes: [1, 2, 3, 4],
                            identityName: 'APTO Solana Pay',
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚡ Transaction signed via ${activeWallet.name}! (${signedBytes?.length ?? 0} bytes)'),
                                backgroundColor: activeWallet.color,
                              ),
                            );
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        child: ElevatedButton(
                          onPressed: null, // Gesture handled by AnimatedPressable
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeWallet.color,
                            disabledBackgroundColor: activeWallet.color,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: Text(
                            'Sign with ${activeWallet.name}',
                            style: AppTheme.sansBody(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Secondary Action: Cancel
              StaggeredEntrance(
                index: 3,
                child: SizedBox(
                  width: double.infinity,
                  child: AnimatedPressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: OutlinedButton(
                      onPressed: null, // Gesture handled by AnimatedPressable
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.outlineBorder, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.sansBody(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
