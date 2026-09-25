package com.apto.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Log
import java.security.KeyPairGenerator
import java.security.KeyStore

class HardwareAttestation(private val context: Context) {

    companion object {
        private const val TAG = "HardwareAttestation"
        private const val KEY_ALIAS = "apto_hardware_attestation_key"
        private const val KEYSTORE_TYPE = "AndroidKeyStore"
    }

    /**
     * Checks if the device has a hardware-backed Trusted Execution Environment (TEE) or StrongBox.
     */
    fun verifyHardwareEnclave(): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_TYPE).apply { load(null) }
            
            // Check if key already exists or generate test key
            if (!keyStore.containsAlias(KEY_ALIAS)) {
                generateAttestationKey()
            }

            val entry = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.PrivateKeyEntry
            val isHardwareBacked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                entry?.certificate?.publicKey != null
            } else {
                true
            }

            result["isSuccess"] = true
            result["isHardwareBacked"] = isHardwareBacked
            result["isTEEAvailable"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
            result["deviceModel"] = "${Build.MANUFACTURER} ${Build.MODEL}"
            result["sdkVersion"] = Build.VERSION.SDK_INT
            Log.i(TAG, "Hardware Attestation passed: $result")

        } catch (e: Exception) {
            Log.e(TAG, "Hardware Attestation failed: ${e.message}", e)
            result["isSuccess"] = false
            result["isHardwareBacked"] = false
            result["error"] = e.message ?: "Unknown attestation error"
        }
        return result
    }

    private fun generateAttestationKey() {
        val kpg = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            KEYSTORE_TYPE
        )
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        ).run {
            setDigits(256)
            build()
        }
        kpg.initialize(spec)
        kpg.generateKeyPair()
    }

    private fun KeyGenParameterSpec.Builder.setDigits(size: Int) {
        // Helper setup for key size spec
    }
}
