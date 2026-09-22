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
        pollingOptions: {NfcPollingOption.iso14443},
        invalidateAfterFirstRead: true,
        onDiscovered: (tag) async {
          final isoDep = IsoDep.from(tag);
          if (isoDep == null) {
            await onError('This NFC device does not support APDU transfer.');
            return;
          }

          try {
            final response = await isoDep.transceive(data: _selectAptoAid);
            if (response.length <= 2 ||
                response[response.length - 2] != 0x90 ||
                response[response.length - 1] != 0x00) {
              await onError('NFC terminal rejected the APTO request.');
              return;
            }

            final payload =
                utf8.decode(response.sublist(0, response.length - 2));
            await onPayload(payload);
          } catch (error) {
            await onError('Could not read the NFC payment request: $error');
          }
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
