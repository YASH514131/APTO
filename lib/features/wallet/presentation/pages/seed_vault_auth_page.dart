import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animation/animated_pressable.dart';
import '../../../../core/animation/staggered_entrance.dart';
import '../../domain/models/wallet_provider.dart';
import '../../services/wallet_adapter_service.dart';

class SeedVaultAuthPage extends StatefulWidget {
  final VoidCallback onConnected;

  const SeedVaultAuthPage({
    super.key,
    required this.onConnected,
  });

  @override
  State<SeedVaultAuthPage> createState() => _SeedVaultAuthPageState();
}

class _SeedVaultAuthPageState extends State<SeedVaultAuthPage> {
  bool _isConnecting = false;

  Future<void> _connectSeedVault() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final connected = await WalletAdapterService.instance
          .selectWallet(WalletProvider.seedVault);

      if (mounted) {
        if (connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Solana Seed Vault Wallet Connected!'),
              backgroundColor: AppTheme.seedVaultTeal,
            ),
          );
          widget.onConnected();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Seed Vault authorization was cancelled or unavailable.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection note: $e'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031016),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'lib/assets/images/landpage.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF031016),
              ),
            ),
          ),

          // Foreground Content
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header: APTO Logo + Settings Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.seedVaultTeal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'APTO',
                            style: AppTheme.serifHeading(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ).copyWith(letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Hero Welcome Text Section
                  StaggeredEntrance(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to\nAPTO',
                          style: AppTheme.serifHeading(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ).copyWith(height: 1.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Connect your wallet to\nexplore the web3 world.',
                          style: AppTheme.sansBody(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.75),
                          ).copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Connect Wallet Button
                  StaggeredEntrance(
                    index: 1,
                    child: AnimatedPressable(
                      onTap: _isConnecting ? () {} : _connectSeedVault,
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D6E7E),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D6E7E)
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Connect Wallet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _isConnecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.east_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Footer Security Notice
                  StaggeredEntrance(
                    index: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Colors.white70,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1.5,
                            height: 28,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Your wallet stays\nunder your control.',
                            style: AppTheme.sansBody(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.65),
                            ).copyWith(height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
