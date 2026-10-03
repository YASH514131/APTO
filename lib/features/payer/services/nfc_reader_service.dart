import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NfcReaderService {
  static final Uint8List _selectAptoAid = Uint8List.fromList([
    0x00,
    0xA4,
    0x04,
    0x00,
    0x05,
    0xF2,
    0x22,
    0x22,
    0x22,
    0x22,
    0x00,
  ]);

  static Future<void> scan({
    required Future<void> Function(String payload) onPayload,
    required Future<void> Function(String message) onError,
  }) async {
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        invalidateAfterFirstRead: true,
        onDiscovered: (tag) async {
          // 1. Try APTO custom APDU via IsoDep (Android HCE peer-to-peer / terminal)
          final isoDep = IsoDep.from(tag);
          if (isoDep != null) {
            try {
              final response = await isoDep.transceive(data: _selectAptoAid);
              if (response.length > 2 &&
                  response[response.length - 2] == 0x90 &&
                  response[response.length - 1] == 0x00) {
                final payload =
                    utf8.decode(response.sublist(0, response.length - 2));
                await onPayload(payload);
                return;
              }
            } catch (error) {
              // Fall through to NDEF check if APDU transceive fails
            }
          }

          // 2. Try standard NDEF NFC tag (Solana Pay standard sticker / card)
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            try {
              final message = ndef.cachedMessage ?? await ndef.read();
              for (final record in message.records) {
                final payloadString =
                    utf8.decode(record.payload, allowMalformed: true);
                if (payloadString.contains('solana:')) {
                  final solanaIndex = payloadString.indexOf('solana:');
                  final cleanUrl = payloadString.substring(solanaIndex);
                  await onPayload(
                      '$cleanUrl|${DateTime.now().millisecondsSinceEpoch}');
                  return;
                }
              }
            } catch (ndefError) {
              // Ignore and fall through to error
            }
          }

          await onError('Could not read payment request from NFC device.');
        },
      );
    } catch (error) {
      await onError('NFC scan could not start: $error');
    }
  }

  static Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Ignore errors if the session is already stopped or tag is out of date.
    }
  }
}
