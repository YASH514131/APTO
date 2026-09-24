import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animation/page_transitions.dart';
import '../../../../core/animation/animated_pressable.dart';
import '../../../../core/animation/staggered_entrance.dart';
import '../widgets/nfc_video_animation_widget.dart';
import 'confirm_payment_screen.dart';

class TapToPayScreen extends StatelessWidget {
  final String amountUsdc;
  final String recipient;

  const TapToPayScreen({
    super.key,
    this.amountUsdc = '12.50 USDC',
    this.recipient = '7xKX...9fQ2',
  });

  void _simulateTapSuccess(BuildContext context) {
    Navigator.of(context).pushReplacement(
      ScaleFadeRouteBuilder(
        page: ConfirmPaymentScreen(
          recipient: recipient,
          amountUsdc: amountUsdc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Screen Header Title
              StaggeredEntrance(
                index: 0,
                child: Column(
                  children: [
                    Text(
                      'Tap to pay',
                      style: AppTheme.serifHeading(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountUsdc,
                      style: AppTheme.sansBody(fontSize: 16, color: AppTheme.seedVaultTeal, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // NFC Transfer Video Animation Widget
              StaggeredEntrance(
                index: 1,
                child: NfcVideoAnimationWidget(
                  videoPath: 'lib/assets/vedio/nfc_wave.mp4',
                  onTap: () => _simulateTapSuccess(context),
                ),
              ),

              const SizedBox(height: 32),

              // Status Instructions
              StaggeredEntrance(
                index: 2,
                child: Column(
                  children: [
                    Text(
                      'Hold your phone to terminal',
                      style: AppTheme.serifHeading(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap phone to send $amountUsdc',
                      style: AppTheme.sansBody(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Cancel Button with AnimatedPressable
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
