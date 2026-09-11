class SolanaConfig {
  static const String devnetRpcUrl = 'https://api.devnet.solana.com';
  static const String mainnetRpcUrl = 'https://api.mainnet-beta.solana.com';
  
  // Default active RPC
  static String get activeRpcUrl => devnetRpcUrl;

  // Solana Pay URL Prefix
  static const String solanaPayScheme = 'solana';

  // cNFT Loyalty Bubblegum Program ID
  static const String bubblegumProgramId = 'BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY';

  // Anti-Relay Proximity threshold in milliseconds
  static const int maxProximityLatencyMs = 2000;
}
