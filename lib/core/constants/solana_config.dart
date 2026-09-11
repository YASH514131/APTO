class SolanaConfig {
  static const String devnetRpcUrl = 'https://api.devnet.solana.com';
  static const String mainnetRpcUrl = 'https://api.mainnet-beta.solana.com';
  
  /// Default Helius API Key
  static const String defaultHeliusApiKey = '384d1f7b-3371-4d6f-8416-5e5ece01b11f';

  /// Helius API Key (loaded from .env, FlutterSecureStorage, or fallback)
  static String heliusApiKey = defaultHeliusApiKey;

  /// Network selection (false = devnet, true = mainnet)
  static bool isMainnet = false;

  /// Returns true if a valid Helius API key is active
  static bool get isHeliusActive => heliusApiKey.trim().isNotEmpty;

  /// Active JSON-RPC HTTP Endpoint
  static String get activeRpcUrl {
    final key = heliusApiKey.trim();
    if (key.isNotEmpty) {
      final cluster = isMainnet ? 'mainnet' : 'devnet';
      return 'https://$cluster.helius-rpc.com/?api-key=$key';
    }
    return isMainnet ? mainnetRpcUrl : devnetRpcUrl;
  }

  /// Active Solana WebSocket (WSS) Endpoint
  static String get activeWebSocketUrl {
    final key = heliusApiKey.trim();
    if (key.isNotEmpty) {
      final cluster = isMainnet ? 'mainnet' : 'devnet';
      return 'wss://$cluster.helius-rpc.com/?api-key=$key';
    }
    return (isMainnet ? mainnetRpcUrl : devnetRpcUrl).replaceAll('https', 'wss');
  }

  // Solana Pay URL Prefix
  static const String solanaPayScheme = 'solana';

  // cNFT Loyalty Bubblegum Program ID
  static const String bubblegumProgramId = 'BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY';

  // Anti-Relay Proximity threshold in milliseconds
  static const int maxProximityLatencyMs = 2000;
}
