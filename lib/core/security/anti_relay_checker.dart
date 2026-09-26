import 'package:flutter/foundation.dart';
import '../constants/solana_config.dart';

class AntiRelayChecker {
  static const int maxAllowedLatencyMs = SolanaConfig.maxProximityLatencyMs;

  /// Verifies whether the NFC payload was received within the acceptable latency threshold
  /// to mitigate remote NFC Relay Attacks.
  static bool isLatencyValid(int apduTimestampMs) {
    final currentTimestampMs = DateTime.now().millisecondsSinceEpoch;
    final delta = currentTimestampMs - apduTimestampMs;

    debugPrint('APTU Security: Proximity latency delta = ${delta}ms');

    if (delta < 0 || delta > maxAllowedLatencyMs) {
      debugPrint('APTU Security Warning: NFC Relay suspected! Delta (${delta}ms) exceeds limit.');
      return false;
    }
    return true;
  }
}
