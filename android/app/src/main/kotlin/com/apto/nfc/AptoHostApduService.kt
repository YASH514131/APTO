package com.apto.nfc

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class AptoHostApduService : HostApduService() {

    companion object {
        private const val TAG = "AptoHostApduService"
        
        // APDU Select Command Header
        private val SELECT_APDU_HEADER = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte()
        )
        
        // Dynamic payload configured via MethodChannel from Flutter
        @JvmStatic
        var currentSolanaPayPayload: String = ""
        
        // Dynamic ephemeral reference pubkey
        @JvmStatic
        var currentReferenceKey: String = ""

        // Status bytes for Success (SW1 SW2 = 0x90 0x00)
        private val SUCCESS_SW = byteArrayOf(0x90.toByte(), 0x00.toByte())
        
        // Status bytes for Command Not Allowed / Fail (0x69 0x86)
        private val FAILURE_SW = byteArrayOf(0x69.toByte(), 0x86.toByte())
    }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (currentSolanaPayPayload.isEmpty()) {
            val preferences = getSharedPreferences("apto_hce", MODE_PRIVATE)
            val storedPayload = preferences.getString("payload", "") ?: ""
            val storedAddress = preferences.getString("addressPayload", "") ?: ""
            currentSolanaPayPayload = if (storedPayload.isNotEmpty()) storedPayload else storedAddress
        }
        if (commandApdu == null) return FAILURE_SW
        
        Log.d(TAG, "APDU Command received: ${commandApdu.toHexString()}")

        // Check if payload is ready
        if (currentSolanaPayPayload.isEmpty()) {
            Log.w(TAG, "No active Solana Pay payload configured!")
            return FAILURE_SW
        }

        val timestamp = System.currentTimeMillis()
        // Format: PAYLOAD|TIMESTAMP
        val fullResponseString = "$currentSolanaPayPayload|$timestamp"
        val payloadBytes = fullResponseString.toByteArray(Charsets.UTF_8)

        // Combine payload bytes with SUCCESS status bytes (0x9000)
        return payloadBytes + SUCCESS_SW
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "HCE Service Deactivated. Reason code: $reason")
    }

    private fun ByteArray.toHexString(): String {
        return joinToString("") { "%02x".format(it) }
    }
}
