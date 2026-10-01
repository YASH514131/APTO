import 'package:flutter/material.dart';
import '../../../../core/services/apto_audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../wallet/services/wallet_adapter_service.dart';
import '../../services/skr_reward_service.dart';
import '../widgets/scratch_card_widget.dart';
import '../utils/skr_format_utils.dart';

class SkrScratchRewardDialog extends StatefulWidget {
  final String txSig;
  final double amountUsd;
  final VoidCallback? onDismissed;

  const SkrScratchRewardDialog({
    super.key,
    required this.txSig,
    required this.amountUsd,
    this.onDismissed,
  });

  static Future<void> show(
    BuildContext context, {
    required String txSig,
    required double amountUsd,
    VoidCallback? onDismissed,
  }) {
    AptoAudioService.playFinalize();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SkrScratchRewardDialog',
      barrierColor: Colors.black.withValues(alpha: 0.86),
      transitionDuration: const Duration(milliseconds: 450),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
      pageBuilder: (_, __, ___) => SkrScratchRewardDialog(
        txSig: txSig,
        amountUsd: amountUsd,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  State<SkrScratchRewardDialog> createState() => _SkrScratchRewardDialogState();
}

class _SkrScratchRewardDialogState extends State<SkrScratchRewardDialog>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  double _rewardSkr = 0.48;
  String _tierName = 'Gold';

  late AnimationController _contentAnimController;
  late Animation<Offset> _headerSlide;
  late Animation<double> _scratchCardScale;
  late Animation<double> _scratchCardFade;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentAnimController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _scratchCardScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _scratchCardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimController,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );

    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentAnimController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    _contentAnimController.forward();
    _claimBackendReward();
  }

  @override
  void dispose() {
    _contentAnimController.dispose();
    super.dispose();
  }

  Future<void> _claimBackendReward() async {
    final pubkey = WalletAdapterService.instance.fullAddressNotifier.value;
    final targetWallet = pubkey.isNotEmpty ? pubkey : 'demo-wallet-1';

    try {
      final res = await SkrRewardService.instance.confirmPayment(
        txSig: widget.txSig,
        userPubkey: targetWallet,
        amountUsd: widget.amountUsd,
      );

      final accrued = (res['accrued'] as num?)?.toDouble() ?? 0.48;
      final tier = res['tier']?.toString() ?? 'Gold';

      if (mounted) {
        setState(() {
          _rewardSkr = accrued > 0 ? accrued : 0.48;
          _tierName = tier[0].toUpperCase() + tier.substring(1);
        });
      }

      await SkrRewardService.instance.addHistoryRecord(
        title: 'Tap & Pay Reward',
        amountSkr: _rewardSkr,
        isCredit: true,
        tier: _tierName,
        txSig: widget.txSig,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _rewardSkr = 0.50;
          _tierName = 'Gold';
        });
      }
      await SkrRewardService.instance.addHistoryRecord(
        title: 'Tap & Pay Reward',
        amountSkr: 0.50,
        isCredit: true,
        tier: 'Gold',
        txSig: widget.txSig,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
        decoration: BoxDecoration(
          color: const Color(0xFF071419), // Dark rich app theme background
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.seedVaultTeal.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.seedVaultTeal.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header (Left aligned with square S icon badge)
            SlideTransition(
              position: _headerSlide,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square "S" icon container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.seedVaultTeal.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.seedVaultTeal.withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.asset(
                        'lib/assets/images/skr_logo.jpg',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'S',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // "Payment Confirmed!" Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppTheme.seedVaultTeal,
                              Color(0xFF7BECE1),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(bounds),
                          child: const Text(
                            'Confirmed!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close button
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary, size: 22),
                    onPressed: () {
                      widget.onDismissed?.call();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Subtitle text
            SlideTransition(
              position: _headerSlide,
              child: const Text(
                'Scratch the card below with your finger to reveal your reward.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ),

            const SizedBox(height: 22),

            // 2. Scratch Card Component (Silver-Lavender Surface with 60 FPS scratch)
            ScaleTransition(
              scale: _scratchCardScale,
              child: FadeTransition(
                opacity: _scratchCardFade,
                child: Center(
                  child: ScratchCardWidget(
                    width: 310,
                    height: 180,
                    onThresholdReached: () {
                      setState(() => _isRevealed = true);
                      AptoAudioService.playFinalize();
                    },
                    revealedChild: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0F2C33),
                            Color(0xFF07191E),
                            Color(0xFF143B45),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppTheme.seedVaultTeal.withValues(alpha: 0.65),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -12,
                            bottom: -12,
                            child: Transform.rotate(
                              angle: -0.20,
                              child: Opacity(
                                opacity: 0.22,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'lib/assets/images/skr_logo.jpg',
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.seedVaultTeal
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.seedVaultTeal
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Text(
                                    '$_tierName Tier Reward'.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.seedVaultTeal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '+${formatSkrAmount(_rewardSkr)} SKR',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Added to your Available Rewards 🎉',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Action Pill Button with Brighter Vibrant App Theme Teal Styling
            SlideTransition(
              position: _buttonSlide,
              child: FadeTransition(
                opacity: _buttonFade,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _isRevealed
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF38E5D6),
                                Color(0xFF4FA8B7),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: _isRevealed ? null : const Color(0xFF0C1D23),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _isRevealed
                            ? const Color(0xFF38E5D6)
                            : AppTheme.seedVaultTeal.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: _isRevealed
                          ? [
                              BoxShadow(
                                color: const Color(0xFF38E5D6)
                                    .withValues(alpha: 0.5),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: _isRevealed
                            ? () {
                                widget.onDismissed?.call();
                                Navigator.of(context).pop();
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Finger touch icon frame
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRevealed
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : AppTheme.seedVaultTeal
                                          .withValues(alpha: 0.18),
                                ),
                                child: Icon(
                                  _isRevealed
                                      ? Icons.check_circle_rounded
                                      : Icons.touch_app_outlined,
                                  color: _isRevealed
                                      ? const Color(0xFF031016)
                                      : AppTheme.seedVaultTeal,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Vertical Divider line
                              Container(
                                width: 1,
                                height: 16,
                                color: _isRevealed
                                    ? Colors.black.withValues(alpha: 0.25)
                                    : AppTheme.seedVaultTeal
                                        .withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 14),

                              // Text (Brighter and high contrast)
                              Text(
                                _isRevealed
                                    ? 'Claim +${formatSkrAmount(_rewardSkr)} SKR'
                                    : 'Scratch Card Above to Reveal',
                                style: TextStyle(
                                  color: _isRevealed
                                      ? const Color(0xFF031016)
                                      : const Color(0xFFD4EFF3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
