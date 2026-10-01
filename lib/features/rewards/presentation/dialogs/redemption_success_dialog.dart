import 'package:flutter/material.dart';
import '../../../../core/services/apto_audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../utils/skr_format_utils.dart';

class RedemptionSuccessDialog extends StatefulWidget {
  final double amountSkr;
  final String destinationWallet;

  const RedemptionSuccessDialog({
    super.key,
    required this.amountSkr,
    required this.destinationWallet,
  });

  static Future<void> show(
    BuildContext context, {
    required double amountSkr,
    required String destinationWallet,
  }) {
    AptoAudioService.playFinalize();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'RedemptionSuccessDialog',
      barrierColor: Colors.black.withValues(alpha: 0.84),
      transitionDuration: const Duration(milliseconds: 450),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.84, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (_, __, ___) => RedemptionSuccessDialog(
        amountSkr: amountSkr,
        destinationWallet: destinationWallet,
      ),
    );
  }

  @override
  State<RedemptionSuccessDialog> createState() => _RedemptionSuccessDialogState();
}

class _RedemptionSuccessDialogState extends State<RedemptionSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _checkScaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _checkScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortWallet = widget.destinationWallet.length > 16
        ? '${widget.destinationWallet.substring(0, 8)}...${widget.destinationWallet.substring(widget.destinationWallet.length - 8)}'
        : widget.destinationWallet;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
        decoration: BoxDecoration(
          color: const Color(0xFF071419),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppTheme.seedVaultTeal.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.seedVaultTeal.withValues(alpha: 0.25),
              blurRadius: 46,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Glowing Animated Success Badge
            ScaleTransition(
              scale: _checkScaleAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.seedVaultTeal.withValues(alpha: 0.25),
                      const Color(0xFF0D323A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppTheme.seedVaultTeal,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.seedVaultTeal.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.seedVaultTeal,
                  size: 42,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 2. Congratulations Header
            Text(
              'Transfer Successful! 🎉',
              textAlign: TextAlign.center,
              style: AppTheme.serifHeading(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your SKR rewards have been successfully redeemed and transferred to your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // 3. Amount & Wallet Detail Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1F25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.seedVaultTeal.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'REDEEMED AMOUNT',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatSkrAmount(widget.amountSkr)} SKR',
                    style: const TextStyle(
                      color: AppTheme.seedVaultTeal,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Divider(color: Color(0xFF14333C), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'To: $shortWallet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.seedVaultTeal,
                  foregroundColor: const Color(0xFF031016),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                  shadowColor: AppTheme.seedVaultTeal.withValues(alpha: 0.4),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
