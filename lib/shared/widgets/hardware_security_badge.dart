import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HardwareSecurityBadge extends StatelessWidget {
  const HardwareSecurityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.seedVaultTeal.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.seedVaultTeal, width: 1.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield, color: AppTheme.seedVaultTeal, size: 18),
          SizedBox(width: 8),
          Text(
            'Seed Vault • TEE Attestation Verified',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
