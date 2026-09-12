import 'package:flutter/material.dart';

class WalletProvider {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isHardwareSecured;
  final String? packageName;

  const WalletProvider({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.isHardwareSecured = false,
    this.packageName,
  });

  static const WalletProvider seedVault = WalletProvider(
    id: 'seed_vault',
    name: 'Seed Vault',
    description: 'Hardware TEE Secured (Solana Seeker)',
    icon: Icons.security_rounded,
    color: Color(0xFF32616B),
    isHardwareSecured: true,
    packageName: 'com.solanamobile.seedvault',
  );

  static const WalletProvider phantom = WalletProvider(
    id: 'phantom',
    name: 'Phantom',
    description: 'Solana Web3 Wallet',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFFAB9FF2),
    packageName: 'app.phantom',
  );

  static const WalletProvider solflare = WalletProvider(
    id: 'solflare',
    name: 'Solflare',
    description: 'Non-Custodial Solana Wallet',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFFC7227),
    packageName: 'com.solflare.mobile',
  );

  static const WalletProvider jupiter = WalletProvider(
    id: 'jupiter',
    name: 'Jupiter Mobile',
    description: 'Solana DeFi & Swap Wallet',
    icon: Icons.swap_horizontal_circle_rounded,
    color: Color(0xFFC7F284),
    packageName: 'ag.jup.mobile',
  );

  static const WalletProvider backpack = WalletProvider(
    id: 'backpack',
    name: 'Backpack',
    description: 'xNFT & Solana Wallet',
    icon: Icons.backpack_rounded,
    color: Color(0xFFE54033),
    packageName: 'app.backpack',
  );

  static const WalletProvider mwaAuto = WalletProvider(
    id: 'mwa_auto',
    name: 'System Default Wallet',
    description: 'Auto-detect via Mobile Wallet Adapter',
    icon: Icons.phonelink_setup_rounded,
    color: Color(0xFF14F195),
  );

  static const List<WalletProvider> supportedWallets = [
    seedVault,
    phantom,
    solflare,
    jupiter,
    backpack,
    mwaAuto,
  ];
}
