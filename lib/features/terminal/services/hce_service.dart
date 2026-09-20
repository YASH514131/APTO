import 'package:flutter/services.dart';

class HceService {
  static const MethodChannel _channel = MethodChannel('com.apto/hce');

  /// Configures native HostCardEmulation to broadcast the given Solana Pay URL payload
  static Future<bool> setTerminalPayload({
    required String payload,
    required String reference,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('setPayload', {
        'payload': payload,
        'reference': reference,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Clears active HCE payload
  static Future<bool> stopTerminalBroadcast() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('clearPayload');
      return success ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> setReceiverAddress({required String address}) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'setReceiverAddress',
        {'address': address},
      );
      return success ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
