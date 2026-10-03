class SolanaConfig {
  static const String devnetRpcUrl = 'https://api.devnet.solana.com';
  static const String mainnetRpcUrl = 'https://api.mainnet-beta.solana.com';

  /// Network selection (false = devnet, true = mainnet)
  static bool isMainnet = false;

  /// HTTP RPC is proxied through the authenticated Render backend.
  static String get activeRpcUrl {
    return 'https://apto-backend.onrender.com/solana/rpc';
  }

  /// Kept for SDK compatibility. Realtime fund alerts use FCM webhooks.
  static String get activeWebSocketUrl {
    return (isMainnet ? mainnetRpcUrl : devnetRpcUrl)
        .replaceFirst('https', 'wss');
  }

  // Solana Pay URL Prefix
  static const String solanaPayScheme = 'solana';

  // cNFT Loyalty Bubblegum Program ID
  static const String bubblegumProgramId =
      'BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY';

  // Anti-Relay Proximity threshold in milliseconds
  static const int maxProximityLatencyMs = 2000;
}
