package com.apto

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.apto.nfc.AptoHostApduService
import com.apto.security.HardwareAttestation

class MainActivity: FlutterFragmentActivity() {
    companion object {
        private const val HCE_CHANNEL = "com.apto/hce"
        private const val ATTESTATION_CHANNEL = "com.apto/attestation"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // HCE MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HCE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setPayload" -> {
                    val payload = call.argument<String>("payload") ?: ""
                    val reference = call.argument<String>("reference") ?: ""
                    AptoHostApduService.currentSolanaPayPayload = payload
                    AptoHostApduService.currentReferenceKey = reference
                    getSharedPreferences("apto_hce", MODE_PRIVATE).edit()
                        .putString("payload", payload)
                        .apply()
                    result.success(true)
                }
                "clearPayload" -> {
                    val addressPayload = getSharedPreferences("apto_hce", MODE_PRIVATE)
                        .getString("addressPayload", "") ?: ""
                    AptoHostApduService.currentSolanaPayPayload = addressPayload
                    AptoHostApduService.currentReferenceKey = ""
                    getSharedPreferences("apto_hce", MODE_PRIVATE).edit()
                        .putString("payload", addressPayload)
                        .apply()
                    result.success(true)
                }
                "setReceiverAddress" -> {
                    val address = call.argument<String>("address") ?: ""
                    if (address.isEmpty()) {
                        result.success(false)
                    } else {
                        getSharedPreferences("apto_hce", MODE_PRIVATE).edit()
                            .putString("addressPayload", "solana:$address?label=APTO%20Wallet&message=Wallet%20address&mode=address")
                            .putString("payload", "solana:$address?label=APTO%20Wallet&message=Wallet%20address&mode=address")
                            .apply()
                        AptoHostApduService.currentSolanaPayPayload =
                            "solana:$address?label=APTO%20Wallet&message=Wallet%20address&mode=address"
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Hardware Attestation MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ATTESTATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "verifyEnclave" -> {
                    val attestation = HardwareAttestation(this@MainActivity)
                    val status = attestation.verifyHardwareEnclave()
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }
    }
}
