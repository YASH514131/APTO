import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../firebase_options.dart';
import 'apto_notification_service.dart';
import 'apto_backend_rpc_client.dart';

Future<void> _handleVerifiedTransferMessage(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] != 'verified_incoming_transfer' ||
      data['network'] != 'devnet' ||
      data['mint'] != 'SOL' ||
      data['signature'] is! String ||
      data['wallet'] is! String ||
      data['amountLamports'] is! String) {
    return;
  }

  final signature = data['signature'] as String;
  final wallet = data['wallet'] as String;
  final amountLamports = int.tryParse(data['amountLamports'] as String);
  if (signature.isEmpty ||
      wallet.isEmpty ||
      amountLamports == null ||
      amountLamports <= 0) {
    return;
  }

  final amountSol = amountLamports / 1000000000;
  final sender =
      data['sender'] is String && (data['sender'] as String).isNotEmpty
          ? data['sender'] as String
          : 'Verified transfer';
  final shortSender = sender.length > 8
      ? '${sender.substring(0, 4)}...${sender.substring(sender.length - 4)}'
      : sender;

  await AptoNotificationService.instance.showCustomNotification(
    title: 'Received +${amountSol.toStringAsFixed(4)} SOL',
    body: 'From: $shortSender • Confirmed on Solana',
    payload: signature,
  );
}

/// Top-level background handler for FCM messages when app is killed or in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  await AptoNotificationService.instance.initialize();
  await _handleVerifiedTransferMessage(message);
}

class AptoFcmService {
  static final AptoFcmService instance = AptoFcmService._internal();

  AptoFcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Holds the active FCM registration token for this device
  final ValueNotifier<String?> fcmTokenNotifier = ValueNotifier<String?>(null);

  bool _isInitialized = false;
  String? _registeredWallet;

  /// Initializes FCM listeners, permissions, and token generation
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Register top-level background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Request notification permissions from user (iOS / Android 13+)
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Enable foreground notification presentation options for Apple / modern Android
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Fetch the device registration token without logging it
      final token = await _messaging.getToken();
      if (token != null) {
        fcmTokenNotifier.value = token;
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        fcmTokenNotifier.value = newToken;
        final wallet = _registeredWallet;
        if (wallet != null) {
          _sendSubscription(wallet, newToken);
        }
      });

      // 4. Handle foreground incoming messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final wallet = _registeredWallet;
        if (wallet == null || message.data['wallet'] != wallet) return;
        _handleVerifiedTransferMessage(message);
      });

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  /// Returns the current device token
  String? get fcmToken => fcmTokenNotifier.value;

  Future<void> registerWallet(String walletAddress) async {
    if (walletAddress.isEmpty) return;

    final previousWallet = _registeredWallet;
    if (previousWallet != null && previousWallet != walletAddress) {
      await _deleteSubscription(previousWallet);
    }
    _registeredWallet = walletAddress;
    final token = fcmTokenNotifier.value ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    fcmTokenNotifier.value = token;
    await _sendSubscription(walletAddress, token);
  }

  Future<void> unregisterWallet() async {
    final wallet = _registeredWallet;
    _registeredWallet = null;
    if (wallet == null || wallet.isEmpty) return;

    await _deleteSubscription(wallet);
  }

  Future<void> _deleteSubscription(String wallet) async {
    try {
      await http
          .delete(
            Uri.parse(
                '${AptoBackendRpcClient.baseUrl}/wallet-monitor/subscriptions/${Uri.encodeComponent(wallet)}'),
            headers: AptoBackendRpcClient.headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> _sendSubscription(String walletAddress, String token) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AptoBackendRpcClient.baseUrl}/wallet-monitor/subscriptions'),
            headers: {
              ...AptoBackendRpcClient.headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'walletAddress': walletAddress,
              'fcmToken': token,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) return;
    } catch (_) {}
  }
}
