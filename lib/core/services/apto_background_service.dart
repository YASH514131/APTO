import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';
import 'apto_notification_service.dart';

/// Helper to read the persisted wallet address from SharedPreferences or FlutterSecureStorage
Future<String?> _readPersistedAddress() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString('apto_connected_wallet_address');
    if (a != null && a.isNotEmpty) return a;
    final b = prefs.getString('mwa_wallet_address');
    if (b != null && b.isNotEmpty) return b;
  } catch (_) {}

  try {
    const secureStorage = FlutterSecureStorage();
    final a = await secureStorage.read(key: 'apto_connected_wallet_address');
    if (a != null && a.isNotEmpty) return a;
    final b = await secureStorage.read(key: 'mwa_wallet_address');
    if (b != null && b.isNotEmpty) return b;
  } catch (_) {}

  return null;
}

/// Public Devnet URLs kept only for legacy service compatibility. The app now
/// uses Render RPC and FCM webhooks for monitoring.
String _bgRpcUrl() {
  return 'https://api.devnet.solana.com';
}

String _bgWssUrl() {
  return 'wss://api.devnet.solana.com';
}

/// Entry-point for the background isolate that runs 24/7 on Android even when app is killed
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize notification channel in this background isolate
  await AptoNotificationService.instance.initialize();

  // Immediately dismiss the foreground service notification so user doesn't see it
  if (service is AndroidServiceInstance) {
    // Set as foreground to prevent being killed, but use silent notification
    service.setAsForegroundService();

    // Use a minimal silent notification that won't bother the user
    service.setForegroundNotificationInfo(
      title: '',
      content: '',
    );

    // Cancel the foreground notification after a brief delay
    Timer(const Duration(seconds: 2), () {
      try {
        AptoNotificationService.instance.cancel(888);
      } catch (_) {}
    });
  }

  String? watchedAddress = await _readPersistedAddress();
  debugPrint(
      'BG Service: Initial address loaded from storage: $watchedAddress');

  int? lastLamports;
  bool baselineSet = false;

  // Send-cooldown: prevents stale RPC responses from causing false notifications after a send
  int? preSendLamports;
  DateTime? lastSendTime;
  const sendCooldown = Duration(seconds: 15);

  bool isFalsePositiveFromSend(int newLamports) {
    if (preSendLamports == null || lastSendTime == null) return false;
    final elapsed = DateTime.now().difference(lastSendTime!);
    if (elapsed > sendCooldown) {
      preSendLamports = null;
      lastSendTime = null;
      return false;
    }
    if (newLamports <= preSendLamports!) {
      debugPrint(
          'BG Service: Suppressed false positive (stale RPC during send cooldown)');
      return true;
    }
    return false;
  }

  // Reuse a single SolanaClient for all RPC calls
  final client = SolanaClient(
    rpcUrl: Uri.parse(_bgRpcUrl()),
    websocketUrl: Uri.parse(_bgWssUrl()),
  );

  WebSocket? bgWebSocket;
  StreamSubscription? bgWsSub;
  Timer? pingTimer;
  Timer? reconnectTimer;
  Timer? watchdogTimer;
  int reconnectAttempts = 0;
  DateTime? lastWsMessageTime;

  void triggerAlert(double amtSol) {
    debugPrint(
        '⚡ BG Service Alert: +$amtSol SOL received instantly while app closed!');
    AptoNotificationService.instance.showReceivedFundNotification(
      amountSol: amtSol,
      sender: 'Solana Devnet',
      signature: '',
      notificationId: AptoNotificationService.defaultFundNotificationId,
    );
  }

  void handleLamportUpdate(int newLamports) {
    if (!baselineSet) {
      final old = lastLamports ?? 0;
      lastLamports = newLamports;
      baselineSet = true;
      if (newLamports > old && !isFalsePositiveFromSend(newLamports)) {
        final delta = newLamports - old;
        triggerAlert(delta / lamportsPerSol);
      }
      return;
    }

    final oldLamports = lastLamports ?? 0;

    if (newLamports > oldLamports) {
      // Check if this is a false positive from a stale RPC response after send
      if (isFalsePositiveFromSend(newLamports)) {
        return;
      }
      lastLamports = newLamports;
      final delta = newLamports - oldLamports;
      triggerAlert(delta / lamportsPerSol);
    } else if (newLamports < oldLamports) {
      // Balance decreased (user sent funds) — record for cooldown protection
      lastLamports = newLamports;
      preSendLamports = oldLamports;
      lastSendTime = DateTime.now();
      debugPrint(
          'BG Service: Balance decreased (send detected), cooldown active');
    } else {
      lastLamports = newLamports;
    }
  }

  Future<void> disconnectWebSocket() async {
    pingTimer?.cancel();
    pingTimer = null;
    reconnectTimer?.cancel();
    reconnectTimer = null;
    watchdogTimer?.cancel();
    watchdogTimer = null;
    try {
      await bgWsSub?.cancel();
      bgWsSub = null;
    } catch (_) {}
    try {
      await bgWebSocket?.close();
      bgWebSocket = null;
    } catch (_) {}
  }

  // Use late closures to break circular reference between reconnect <-> connect
  late void Function() scheduleReconnect;
  late Future<void> Function() connectWebSocket;

  connectWebSocket = () async {
    if (watchedAddress == null || watchedAddress!.isEmpty) return;

    await disconnectWebSocket();

    try {
      final wsUrl = _bgWssUrl();
      debugPrint('BG Service: Connecting to RPC WebSocket');

      bgWebSocket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 10),
      );

      reconnectAttempts = 0;
      lastWsMessageTime = DateTime.now();

      // Keep the websocket alive without waking the device unnecessarily.
      pingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (bgWebSocket != null) {
          try {
            bgWebSocket!.add(jsonEncode({
              'jsonrpc': '2.0',
              'id': 999,
              'method': 'getHealth',
            }));
          } catch (e) {
            debugPrint('BG Service: Ping failed: $e');
          }
        }
      });

      // Watchdog: if no message received in 3 minutes, force reconnect.
      watchdogTimer = Timer.periodic(const Duration(minutes: 2), (_) {
        if (lastWsMessageTime != null) {
          final staleDuration = DateTime.now().difference(lastWsMessageTime!);
          if (staleDuration.inMinutes >= 3) {
            debugPrint(
                'BG Service: WebSocket stale for ${staleDuration.inSeconds}s, forcing reconnect');
            reconnectTimer?.cancel();
            reconnectTimer =
                Timer(const Duration(seconds: 1), connectWebSocket);
          }
        }
      });

      // Subscribe to live account changes
      final payload = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'accountSubscribe',
        'params': [
          watchedAddress,
          {'encoding': 'jsonParsed', 'commitment': 'confirmed'}
        ]
      });

      bgWebSocket!.add(payload);

      bgWsSub = bgWebSocket!.listen(
        (data) {
          lastWsMessageTime = DateTime.now();
          try {
            final text = data is String ? data : utf8.decode(data as List<int>);
            final decoded = jsonDecode(text);
            if (decoded is Map<String, dynamic> &&
                decoded['method'] == 'accountNotification') {
              final params = decoded['params'];
              if (params is Map<String, dynamic>) {
                final result = params['result'];
                if (result is Map<String, dynamic>) {
                  final value = result['value'];
                  if (value is Map<String, dynamic> &&
                      value['lamports'] != null) {
                    final raw = value['lamports'];
                    if (raw is num) {
                      handleLamportUpdate(raw.toInt());
                    }
                  }
                }
              }
            }
          } catch (_) {}
        },
        onError: (e) {
          debugPrint('BG Service: WebSocket error: $e');
          scheduleReconnect();
        },
        onDone: () {
          debugPrint('BG Service: WebSocket closed');
          scheduleReconnect();
        },
        cancelOnError: true,
      );

      debugPrint('BG Service: WebSocket connected and subscribed successfully');
    } catch (e) {
      debugPrint('BG Service: WebSocket connect error: $e');
      scheduleReconnect();
    }
  };

  scheduleReconnect = () {
    pingTimer?.cancel();
    watchdogTimer?.cancel();
    reconnectTimer?.cancel();
    reconnectAttempts++;
    // Exponential backoff: 3s, 6s, 9s, ... capped at 30s
    final delaySec = (reconnectAttempts * 3).clamp(3, 30);
    debugPrint(
        'BG Service: Reconnecting in ${delaySec}s (attempt $reconnectAttempts)');
    reconnectTimer = Timer(Duration(seconds: delaySec), connectWebSocket);
  };

  // Listen for dynamic updates from foreground UI
  service.on('setAddress').listen((event) async {
    if (event != null && event['address'] != null) {
      final newAddr = event['address'] as String;
      watchedAddress = newAddr;
      debugPrint('BG Service: Updated watching address: $watchedAddress');

      if (watchedAddress!.isNotEmpty) {
        try {
          final bal = await client.rpcClient
              .getBalance(watchedAddress!)
              .timeout(const Duration(seconds: 5));
          lastLamports = bal.value;
          baselineSet = true;
        } catch (_) {
          lastLamports = 0;
          baselineSet = true;
        }
        await connectWebSocket();
      } else {
        await disconnectWebSocket();
        service.stopSelf();
      }
    }
  });

  service.on('stopService').listen((event) async {
    await disconnectWebSocket();
    service.stopSelf();
  });

  // Ping from foreground to check if service is alive
  service.on('ping').listen((event) {
    debugPrint('BG Service: Received ping, service is alive');
  });

  // Signal from foreground: user just sent a transaction, activate send-cooldown
  service.on('notifySend').listen((event) {
    preSendLamports = lastLamports;
    lastSendTime = DateTime.now();
    debugPrint('BG Service: Send cooldown activated via IPC');
  });

  // Initial connect if address is available from storage
  if (watchedAddress != null && watchedAddress!.isNotEmpty) {
    try {
      final bal = await client.rpcClient
          .getBalance(watchedAddress!)
          .timeout(const Duration(seconds: 5));
      lastLamports = bal.value;
      baselineSet = true;
    } catch (_) {
      lastLamports = 0;
      baselineSet = true;
    }
    connectWebSocket();
  }

  // Safety fallback only runs when the websocket is unavailable. Polling while a
  // subscription is healthy duplicates account updates and wastes battery.
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    // Try to re-read address if it was null
    if (watchedAddress == null || watchedAddress!.isEmpty) {
      watchedAddress = await _readPersistedAddress();
      if (watchedAddress != null &&
          watchedAddress!.isNotEmpty &&
          bgWebSocket == null) {
        connectWebSocket();
      }
    }

    if (watchedAddress == null || watchedAddress!.isEmpty) return;

    if (bgWebSocket != null && bgWsSub != null) return;

    try {
      final balResult = await client.rpcClient
          .getBalance(watchedAddress!)
          .timeout(const Duration(seconds: 5));
      handleLamportUpdate(balResult.value);
    } catch (_) {}

    // Check if WebSocket is dead and reconnect
    if (bgWebSocket == null &&
        watchedAddress != null &&
        watchedAddress!.isNotEmpty) {
      debugPrint('BG Service: Poller detected dead WebSocket, reconnecting...');
      connectWebSocket();
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

class AptoBackgroundService {
  static final AptoBackgroundService instance =
      AptoBackgroundService._internal();

  AptoBackgroundService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
    try {
      // Dismiss any lingering background service notification
      await AptoNotificationService.instance.cancel(888);

      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onBackgroundServiceStart,
          autoStart: false,
          // MUST be true so Android doesn't kill the isolate after ~1 minute
          isForegroundMode: true,
          // Use silent notification channel so the user doesn't see it
          notificationChannelId: AptoNotificationService.silentChannelId,
          initialNotificationTitle: '',
          initialNotificationContent: '',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [AndroidForegroundType.dataSync],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onBackgroundServiceStart,
          onBackground: onIosBackground,
        ),
      );
      debugPrint(
          'AptoBackgroundService configured successfully (isForegroundMode: true, silent channel).');
    } catch (e) {
      debugPrint('AptoBackgroundService configuration error: $e');
    }
  }

  /// Starts the background service safely and sends the active wallet address
  Future<void> updateWatchedAddress(String address) async {
    try {
      if (address.isNotEmpty) {
        // Also persist to SharedPreferences from foreground
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('apto_connected_wallet_address', address);
        } catch (_) {}

        final isRunning = await _service.isRunning();
        if (!isRunning) {
          await _service.startService();
          // Give isolate a moment to boot before sending address
          await Future.delayed(const Duration(milliseconds: 800));
        }
        _service.invoke('setAddress', {'address': address});
      } else {
        _service.invoke('setAddress', {'address': ''});
      }
    } catch (e) {
      debugPrint('AptoBackgroundService updateWatchedAddress note: $e');
    }
  }

  /// Checks if the background service is running and restarts it if needed
  Future<void> ensureRunning(String address) async {
    if (address.isEmpty) return;
    try {
      final isRunning = await _service.isRunning();
      if (!isRunning) {
        debugPrint('AptoBackgroundService: Service was dead, restarting...');
        await _service.startService();
        await Future.delayed(const Duration(milliseconds: 800));
        _service.invoke('setAddress', {'address': address});
      }
    } catch (e) {
      debugPrint('AptoBackgroundService ensureRunning note: $e');
    }
  }

  /// Notifies the background isolate that the user just sent a transaction,
  /// so it can activate its send-cooldown and suppress false 'received' notifications
  void notifySend() {
    try {
      _service.invoke('notifySend');
    } catch (_) {}
  }

  /// Stops background monitoring
  void stop() {
    try {
      _service.invoke('stopService');
    } catch (_) {}
  }
}
