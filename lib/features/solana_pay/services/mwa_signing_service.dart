import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

class MwaSigningService {
  /// Maximum number of retry attempts for MWA operations
  static const int _maxRetries = 2;

  /// Timeout for the MWA scenario handshake (Seed Vault opening)
  static const Duration _scenarioStartTimeout = Duration(seconds: 30);

  /// Timeout for authorization/reauthorization
  static const Duration _authTimeout = Duration(seconds: 90);

  /// Timeout for signing
  static const Duration _signTimeout = Duration(seconds: 90);

  static Future<AuthorizationResult?> authorizeWallet({
    required String identityName,
    String? authToken,
  }) async {
    // Try with retry logic
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      final result = await _attemptAuthorize(
        identityName: identityName,
        authToken: authToken,
        attempt: attempt,
      );
      if (result != null) return result;

      // If reauthorize failed, clear authToken and retry with fresh authorize
      if (authToken != null && attempt == 0) {
        debugPrint('MWA: Reauthorize failed, retrying with fresh authorize...');
        authToken = null;
        continue;
      }

      // Wait briefly before retry to let Seed Vault settle
      if (attempt < _maxRetries) {
        debugPrint('MWA: Authorization attempt ${attempt + 1} failed, retrying in 1s...');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    debugPrint('MWA: All authorization attempts failed.');
    return null;
  }

  static Future<AuthorizationResult?> _attemptAuthorize({
    required String identityName,
    String? authToken,
    int attempt = 0,
  }) async {
    LocalAssociationScenario? scenario;
    try {
      scenario = await LocalAssociationScenario.create();
      unawaited(scenario.startActivityForResult(null));

      final client = await scenario.start().timeout(_scenarioStartTimeout);

      AuthorizationResult? result;

      if (authToken != null) {
        // Try reauthorize first with existing token
        try {
          result = await client
              .reauthorize(
                identityUri: Uri.parse('https://apto.app'),
                iconUri: null,
                identityName: identityName,
                authToken: authToken,
              )
              .timeout(_authTimeout);
        } catch (e) {
          debugPrint('MWA: Reauthorize failed (will try fresh authorize): $e');
          // Fall through to fresh authorize below
        }

        // If reauthorize failed, try fresh authorize in same session
        if (result == null) {
          try {
            result = await client
                .authorize(
                  identityUri: Uri.parse('https://apto.app'),
                  iconUri: null,
                  identityName: identityName,
                  cluster: 'devnet',
                )
                .timeout(_authTimeout);
          } catch (e) {
            debugPrint('MWA: Fallback authorize also failed: $e');
          }
        }
      } else {
        // Fresh authorize (no existing token)
        result = await client
            .authorize(
              identityUri: Uri.parse('https://apto.app'),
              iconUri: null,
              identityName: identityName,
              cluster: 'devnet',
            )
            .timeout(_authTimeout);
      }

      return result;
    } on TimeoutException {
      debugPrint('MWA: Authorization timed out (attempt $attempt)');
      return null;
    } catch (e) {
      debugPrint('MWA: Authorization exception (attempt $attempt): $e');
      return null;
    } finally {
      try {
        await scenario?.close();
      } catch (_) {}
    }
  }

  /// Invokes Mobile Wallet Adapter (MWA) to request transaction signature from Seed Vault / Wallet
  /// Includes automatic retry, auth token refresh fallback, and robust error handling
  static Future<List<int>?> signTransaction({
    required List<int> unsignedTransactionBytes,
    required String identityName,
    String? authToken,
  }) async {
    // Try with retry logic
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      final result = await _attemptSign(
        unsignedTransactionBytes: unsignedTransactionBytes,
        identityName: identityName,
        authToken: authToken,
        attempt: attempt,
      );
      if (result != null) return result;

      // If reauthorize failed during signing, clear authToken and retry with fresh authorize
      if (authToken != null && attempt == 0) {
        debugPrint('MWA: Sign with reauthorize failed, retrying with fresh authorize...');
        authToken = null;
        continue;
      }

      // Wait briefly before retry
      if (attempt < _maxRetries) {
        debugPrint('MWA: Sign attempt ${attempt + 1} failed, retrying in 1s...');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    debugPrint('MWA: All sign attempts failed.');
    return null;
  }

  static Future<List<int>?> _attemptSign({
    required List<int> unsignedTransactionBytes,
    required String identityName,
    String? authToken,
    int attempt = 0,
  }) async {
    LocalAssociationScenario? scenario;
    try {
      scenario = await LocalAssociationScenario.create();
      unawaited(scenario.startActivityForResult(null));

      final client = await scenario.start().timeout(_scenarioStartTimeout);

      // Step 1: Authorize or reauthorize
      AuthorizationResult? authorizationResult;

      if (authToken != null) {
        // Try reauthorize first
        try {
          authorizationResult = await client
              .reauthorize(
                identityUri: Uri.parse('https://apto.app'),
                iconUri: null,
                identityName: identityName,
                authToken: authToken,
              )
              .timeout(_authTimeout);
        } catch (e) {
          debugPrint('MWA: Reauthorize in sign failed: $e');
        }

        // Fallback to fresh authorize if reauthorize failed
        if (authorizationResult == null) {
          debugPrint('MWA: Reauthorize returned null during signing, falling back to fresh authorize...');
          try {
            authorizationResult = await client
                .authorize(
                  identityUri: Uri.parse('https://apto.app'),
                  iconUri: null,
                  identityName: identityName,
                  cluster: 'devnet',
                )
                .timeout(_authTimeout);
          } catch (e) {
            debugPrint('MWA: Fallback authorize in sign also failed: $e');
          }
        }
      } else {
        // Fresh authorize
        authorizationResult = await client
            .authorize(
              identityUri: Uri.parse('https://apto.app'),
              iconUri: null,
              identityName: identityName,
              cluster: 'devnet',
            )
            .timeout(_authTimeout);
      }

      if (authorizationResult == null) {
        debugPrint('MWA: Authorization failed or rejected by user (attempt $attempt).');
        return null;
      }

      // Step 2: Sign the transaction
      final signResult = await client
          .signTransactions(
            transactions: [Uint8List.fromList(unsignedTransactionBytes)],
          )
          .timeout(_signTimeout);

      if (signResult.signedPayloads.isNotEmpty) {
        debugPrint('MWA: Transaction signed successfully (attempt $attempt).');
        return signResult.signedPayloads.first;
      }

      debugPrint('MWA: signTransactions returned empty payloads (attempt $attempt).');
      return null;
    } on TimeoutException {
      debugPrint('MWA: Sign timed out (attempt $attempt)');
      return null;
    } catch (e) {
      debugPrint('MWA: Sign exception (attempt $attempt): $e');
      return null;
    } finally {
      try {
        await scenario?.close();
      } catch (_) {}
    }
  }
}
