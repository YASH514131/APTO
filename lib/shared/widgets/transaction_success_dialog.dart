import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/services/apto_audio_service.dart';
import '../../core/theme/app_theme.dart';

class TransactionSuccessDialog extends StatelessWidget {
  final String signature;
  final String title;

  const TransactionSuccessDialog({
    super.key,
    required this.signature,
    this.title = 'Transaction confirmed',
  });

  static Future<void> show(
    BuildContext context, {
    required String signature,
    String title = 'Transaction confirmed',
  }) {
    AptoAudioService.playFinalize();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransactionSuccessDialog(
        signature: signature,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortSignature = signature.length > 16
        ? '${signature.substring(0, 8)}...${signature.substring(signature.length - 8)}'
        : signature;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(28),
          border:
              Border.all(color: AppTheme.solanaGreen.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.solanaGreen.withValues(alpha: 0.16),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(
              width: 140,
              height: 140,
              child: SmoothSuccessCheckmark(),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.serifHeading(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Confirmed on Solana Devnet',
              style:
                  AppTheme.sansBody(fontSize: 13, color: AppTheme.solanaGreen),
            ),
            const SizedBox(height: 14),
            SelectableText(
              shortSignature,
              textAlign: TextAlign.center,
              style: AppTheme.sansBody(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.seedVaultTeal,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'lib/assets/images/logo.jpg',
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'POWERED BY APTO',
                  style: AppTheme.sansBody(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A buttery 60/120 FPS GPU-accelerated vector checkmark animation.
/// Plays ONCE from 0.0 to 1.0 with an elastic pop + path draw, then stops cleanly on the tick.
class SmoothSuccessCheckmark extends StatefulWidget {
  const SmoothSuccessCheckmark({super.key});

  @override
  State<SmoothSuccessCheckmark> createState() => _SmoothSuccessCheckmarkState();
}

class _SmoothSuccessCheckmarkState extends State<SmoothSuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOutCubic),
    );

    // Run EXACTLY ONCE and stop at completed tick
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _CheckmarkPainter(
            scaleProgress: _scaleAnimation.value,
            checkProgress: _checkAnimation.value,
            greenColor: AppTheme.solanaGreen,
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double scaleProgress;
  final double checkProgress;
  final Color greenColor;

  _CheckmarkPainter({
    required this.scaleProgress,
    required this.checkProgress,
    required this.greenColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.82;

    // 1. Draw glowing background circle
    final glowPaint = Paint()
      ..color = greenColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius * math.max(0.0, scaleProgress), glowPaint);

    final bgPaint = Paint()
      ..color = greenColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * math.max(0.0, scaleProgress), bgPaint);

    final ringPaint = Paint()
      ..color = greenColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius * math.max(0.0, scaleProgress), ringPaint);

    // 2. Draw Checkmark (Tick) Path incrementally
    if (checkProgress > 0) {
      final p1 = Offset(center.dx - radius * 0.35, center.dy + radius * 0.02);
      final p2 = Offset(center.dx - radius * 0.08, center.dy + radius * 0.30);
      final p3 = Offset(center.dx + radius * 0.38, center.dy - radius * 0.25);

      final strokePaint = Paint()
        ..color = greenColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      path.moveTo(p1.dx, p1.dy);

      if (checkProgress <= 0.4) {
        final t = checkProgress / 0.4;
        final currentX = p1.dx + (p2.dx - p1.dx) * t;
        final currentY = p1.dy + (p2.dy - p1.dy) * t;
        path.lineTo(currentX, currentY);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final t = (checkProgress - 0.4) / 0.6;
        final currentX = p2.dx + (p3.dx - p2.dx) * t;
        final currentY = p2.dy + (p3.dy - p2.dy) * t;
        path.lineTo(currentX, currentY);
      }

      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.scaleProgress != scaleProgress ||
        oldDelegate.checkProgress != checkProgress;
  }
}
