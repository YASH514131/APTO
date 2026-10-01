import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool isWarning;

  const AppErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.isWarning = false,
  });

  static String friendlyMessage(String technicalMessage) {
    final message = technicalMessage.toLowerCase();

    if (message.contains('too many requests') ||
        message.contains('rate limit') ||
        message.contains('429') ||
        message.contains('timeout') ||
        message.contains('socketexception') ||
        message.contains('network')) {
      return 'The connection is busy right now. Your wallet is safe. Please try again in a moment.';
    }
    if (message.contains('insufficient funds') ||
        message.contains('insufficient lamports')) {
      return 'There isn’t enough SOL in this wallet to complete the payment.';
    }
    if (message.contains('invalid nfc') ||
        message.contains('format') ||
        message.contains('public key')) {
      return 'We could not read a valid payment request. Ask the other person to refresh their tap screen and try again.';
    }
    if (message.contains('biometric') || message.contains('fingerprint')) {
      return 'Authentication was not completed. Please try again and approve the request on your device.';
    }
    if (message.contains('relay') || message.contains('proximity')) {
      return 'The tap took too long to verify. Keep the devices close together and try again.';
    }
    if (message.contains('cancel') || message.contains('rejected')) {
      return 'The wallet did not approve this request. No new payment was submitted.';
    }
    if (message.contains('available balance') ||
        message.contains('exceeds available')) {
      return technicalMessage;
    }
    if (message.contains('connect your') ||
        message.contains('please connect')) {
      return 'Connect your wallet before continuing.';
    }

    return 'We could not complete that just now. Check your wallet activity before trying again.';
  }

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String technicalMessage,
    bool isWarning = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AppErrorDialog(
        title: title,
        message: friendlyMessage(technicalMessage),
        isWarning: isWarning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        isWarning ? const Color(0xFFE6A35C) : const Color(0xFFE27D72);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: Icon(
                isWarning
                    ? Icons.touch_app_rounded
                    : Icons.error_outline_rounded,
                color: accent,
                size: 27,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.serifHeading(
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.sansBody(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.seedVaultTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
