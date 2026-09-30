import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AptoNotificationService {
  static final AptoNotificationService instance =
      AptoNotificationService._internal();

  AptoNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'apto_fund_transfers';
  static const String channelName = 'Incoming Fund Transfers';
  static const String channelDescription =
      'Real-time alerts when incoming SOL or tokens are received.';

  static const String silentChannelId = 'apto_silent_guard';
  static const String silentChannelName = 'APTO Background Sync';

  bool _isInitialized = false;

  /// Initializes the local notification plugin and configures Android notification channel
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // 1. High-priority channel for incoming funds alerts
          const androidChannel = AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          );
          await androidPlugin.createNotificationChannel(androidChannel);

          // 2. Silent low-priority channel for background service
          const silentChannel = AndroidNotificationChannel(
            silentChannelId,
            silentChannelName,
            description: 'Background wallet monitoring service',
            importance: Importance.min,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          );
          await androidPlugin.createNotificationChannel(silentChannel);

          // Request notification permissions for Android 13+ (API 33+)
          await androidPlugin.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
      debugPrint('AptoNotificationService: Initialized successfully.');
    } catch (e) {
      debugPrint('AptoNotificationService initialization error: $e');
    }
  }

  /// Explicitly requests notification permissions at runtime (especially for Android 13+ and iOS)
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          debugPrint('AptoNotificationService: Android POST_NOTIFICATIONS permission = $granted');
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('AptoNotificationService requestPermission note: $e');
    }
    return true;
  }

  static const int defaultFundNotificationId = 777;
  DateTime? _lastFundAlertTime;
  double? _lastFundAlertAmount;

  /// Cancels a notification by its ID
  Future<void> cancel(int id) async {
    try {
      await _localNotifications.cancel(id);
    } catch (_) {}
  }

  /// Displays an instant high-priority system notification in the status bar styled to APTO theme
  Future<void> showReceivedFundNotification({
    required double amountSol,
    required String sender,
    required String signature,
    int? notificationId,
  }) async {
    try {
      // Deduplication guard: suppress duplicate alerts for the same amount within 4 seconds
      final now = DateTime.now();
      final isEnrichment = signature.isNotEmpty && sender != 'Solana Devnet';
      if (!isEnrichment &&
          _lastFundAlertTime != null &&
          now.difference(_lastFundAlertTime!) < const Duration(seconds: 4) &&
          _lastFundAlertAmount == amountSol) {
        debugPrint(
            'AptoNotificationService: Suppressing duplicate fund notification within 4s window.');
        return;
      }
      _lastFundAlertTime = now;
      _lastFundAlertAmount = amountSol;

      final formattedAmt = amountSol >= 1.0
          ? '+ ${amountSol.toStringAsFixed(3)} SOL'
          : '+ ${amountSol.toStringAsFixed(4)} SOL';

      // Estimated USD equivalent (~180 USD/SOL rate)
      final approxUsd = (amountSol * 180.0).toStringAsFixed(2);

      final shortSender = sender.length > 8
          ? '${sender.substring(0, 4)}...${sender.substring(sender.length - 4)}'
          : sender;

      final title = 'Received $formattedAmt';
      final body = 'From: $shortSender • Confirmed on Solana';

      final expandedText =
          'Amount: $formattedAmt (~USD \$$approxUsd)\n'
          'From: $shortSender\n'
          'Network: Solana Devnet • Confirmed';

      const themeTeal = Color(0xFF0D6E7E);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'APTO: $formattedAmt Received',
        icon: '@mipmap/ic_launcher',
        color: themeTeal,
        subText: 'Solana Devnet',
        category: AndroidNotificationCategory.status,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          expandedText,
          contentTitle: title,
          summaryText: 'APTO Wallet',
        ),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      // Consistent ID ensures notifications update cleanly in-place without duplicating
      final id = notificationId ?? defaultFundNotificationId;

      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: signature,
      );

      debugPrint('AptoNotificationService: System push notification posted (id: $id).');
    } catch (e) {
      debugPrint('AptoNotificationService show error: $e');
    }
  }

  /// Displays a custom notification (used by FCM or remote push)
  Future<void> showCustomNotification({
    required String title,
    required String body,
    String payload = '',
    int? notificationId,
  }) async {
    try {
      const themeTeal = Color(0xFF0D6E7E);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: themeTeal,
        subText: 'APTO Wallet',
        category: AndroidNotificationCategory.event,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Solana Devnet',
        ),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final id = notificationId ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint('AptoNotificationService: Custom/FCM notification posted (id: $id).');
    } catch (e) {
      debugPrint('AptoNotificationService showCustom error: $e');
    }
  }
}


