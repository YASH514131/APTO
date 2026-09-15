import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/wallet_provider.dart';
import '../../services/wallet_adapter_service.dart';

class WalletSelectorSheet extends StatefulWidget {
  const WalletSelectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const WalletSelectorSheet(),
      ),
    );
  }

  @override
  State<WalletSelectorSheet> createState() => _WalletSelectorSheetState();
}

class _WalletSelectorSheetState extends State<WalletSelectorSheet> {
  final TextEditingController _customAddressController =
      TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppTheme.outlineBorder, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom Sheet Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Wallet Provider',
                    style: AppTheme.serifHeading(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Text(
                'Choose your default Solana wallet for tap-to-pay signatures.',
                style: AppTheme.sansBody(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 20),

              // Wallet Providers List
              ValueListenableBuilder<WalletProvider>(
                valueListenable:
                    WalletAdapterService.instance.activeWalletNotifier,
                builder: (context, activeWallet, child) {
                  return Column(
                    children: WalletProvider.supportedWallets.map((provider) {
                      final isSelected = activeWallet.id == provider.id;

                      return GestureDetector(
                        onTap: () async {
                          final connected = await WalletAdapterService.instance
                              .selectWallet(provider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  connected
                                      ? '⚡ Connected to ${provider.name}'
                                      : 'Could not connect to ${provider.name}.',
                                ),
                                backgroundColor: connected
                                    ? provider.color
                                    : Colors.orangeAccent,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            if (connected) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? provider.color.withValues(alpha: 0.15)
                                : AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? provider.color
                                  : Colors.white.withValues(alpha: 0.05),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Wallet Icon Container
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: provider.color.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(provider.icon,
                                    color: provider.color, size: 22),
                              ),

                              const SizedBox(width: 14),

                              // Wallet Name & Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          provider.name,
                                          style: AppTheme.sansBody(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (provider.isHardwareSecured) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.seedVaultTeal
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: AppTheme.seedVaultTeal,
                                                  width: 0.8),
                                            ),
                                            child: Text(
                                              'TEE HARDWARE',
                                              style: AppTheme.sansBody(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.seedVaultTeal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.description,
                                      style: AppTheme.sansBody(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Radio Selection Indicator
                              if (isSelected)
                                Icon(Icons.check_circle_rounded,
                                    color: provider.color, size: 24)
                              else
                                Icon(Icons.circle_outlined,
                                    color: AppTheme.textSecondary
                                        .withValues(alpha: 0.4),
                                    size: 24),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 12),
              const Divider(color: AppTheme.outlineBorder, height: 1),
              const SizedBox(height: 16),

              // Devnet Live Tools (Custom Address & Airdrop)
              Text(
                'Solana Devnet Tools',
                style: AppTheme.sansBody(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // Airdrop Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final success = await WalletAdapterService.instance
                            .requestDevnetAirdrop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '⚡ 1 SOL Airdropped on Devnet!'
                                  : '❌ Airdrop limit reached or RPC offline.'),
                              backgroundColor: success
                                  ? AppTheme.solanaGreen
                                  : Colors.redAccent,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.water_drop_outlined,
                          color: AppTheme.solanaGreen, size: 16),
                      label: Text(
                        '1 SOL Airdrop',
                        style: AppTheme.sansBody(
                            fontSize: 13,
                            color: AppTheme.solanaGreen,
                            fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppTheme.solanaGreen, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Custom PubKey Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showCustomInput = !_showCustomInput;
                        });
                      },
                      icon: const Icon(Icons.edit_note_rounded,
                          color: AppTheme.seedVaultTeal, size: 18),
                      label: Text(
                        _showCustomInput ? 'Hide Input' : 'Enter PubKey',
                        style: AppTheme.sansBody(
                            fontSize: 13,
                            color: AppTheme.seedVaultTeal,
                            fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppTheme.seedVaultTeal, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),

              if (_showCustomInput) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _customAddressController,
                  style: AppTheme.sansBody(
                      fontSize: 13, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter Solana Base58 Public Key...',
                    hintStyle: AppTheme.sansBody(
                        fontSize: 12, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.outlineBorder),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded,
                          color: AppTheme.seedVaultTeal),
                      onPressed: () {
                        final val = _customAddressController.text.trim();
                        if (val.isNotEmpty) {
                          WalletAdapterService.instance.setWalletAddress(val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '⚡ Connected to custom address: ${val.substring(0, 6)}...'),
                              backgroundColor: AppTheme.seedVaultTeal,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
