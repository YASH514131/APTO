import 'package:flutter/services.dart';

class AttestationService {
  static const MethodChannel _channel = MethodChannel('com.apto/attestation');

  /// Queries the Android KeyAttestation status via MethodChannel
  static Future<Map<String, dynamic>> verifyHardwareEnclave() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('verifyEnclave');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      return {
        'isSuccess': false,
        'isHardwareBacked': false,
        'error': e.message,
      };
    }
    return {
      'isSuccess': false,
      'isHardwareBacked': false,
      'error': 'No response from native attestation channel',
    };
  }
}
