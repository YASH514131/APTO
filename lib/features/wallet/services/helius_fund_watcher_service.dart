import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:solana/solana.dart';
import '../../../core/constants/solana_config.dart';
import '../../../core/services/apto_audio_service.dart';
import '../../../core/services/apto_notification_service.dart';
import 'wallet_adapter_service.dart';

class HeliusFundWatcherService {
  static final HeliusFundWatcherService instance =
      HeliusFundWatcherService._internal();

  HeliusFundWatcherService._internal();

  /// Connection status of the real-time WebSocket listener
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);

  WebSocket? _webSocket;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  Timer? _fallbackPollTimer;
  Timer? _pingTimer;
  String? _watchedAddress;
  int? _lastKnownLamports;
  bool _hasBaselineBeenSet = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  /// Tracks the balance BEFORE a send so stale RPC responses don't cause false alerts
  int? _preSendLamports;
  DateTime? _lastSendTime;
  static const Duration _sendCooldown = Duration(seconds: 15);

  /// Call this when the user initiates a send transaction to suppress false notifications
  void notifySendInitiated() {
    _preSendLamports = _lastKnownLamports;
    _lastSendTime = DateTime.now();
    debugPrint(
        'Helius Watcher: Send cooldown started (pre-send balance: ${(_preSendLamports ?? 0) / lamportsPerSol} SOL)');
  }

  /// Starts real-time monitoring of incoming funds for the given address
  Future<void> startWatching(String address) async {
    try {
      if (address.isEmpty) return;
      if (_watchedAddress == address && isListeningNotifier.value) return;

      _watchedAddress = address;
      _isDisposed = false;
      _reconnectAttempts = 0;
      _hasBaselineBeenSet = false;

      // Ensure notification permission is requested when watching begins
      unawaited(AptoNotificationService.instance.requestPermission());

      await _initializeBaselineBalance(address);
      await _connectWebSocket();
      _startFallbackPoller();
    } catch (e) {
      debugPrint('Helius Watcher startWatching note: $e');
    }
  }

  /// Stops watching and disconnects WebSocket
  Future<void> stopWatching() async {
    _isDisposed = true;
    _watchedAddress = null;
    _lastKnownLamports = null;
    _hasBaselineBeenSet = false;
    _reconnectTimer?.cancel();
    _fallbackPollTimer?.cancel();
    _pingTimer?.cancel();
    await _disconnectWebSocket();
  }

  Future<void> _initializeBaselineBalance(String address) async {
    try {
      final client = SolanaClient(
        rpcUrl: Uri.parse(SolanaConfig.activeRpcUrl),
        websocketUrl: Uri.parse(SolanaConfig.activeWebSocketUrl),
      );
      final balResult = await client.rpcClient.getBalance(address).timeout(
            const Duration(seconds: 4),
          );
      _lastKnownLamports = balResult.value;
      _hasBaselineBeenSet = true;
      debugPrint(
          'Helius Watcher: Baseline balance initialized: ${_lastKnownLamports! / lamportsPerSol} SOL');
    } catch (e) {
      debugPrint(
          'Helius Watcher: Baseline fetch note (assuming 0 SOL for new account): $e');
      _lastKnownLamports ??= 0;
      _hasBaselineBeenSet = true;
    }
  }

  Future<void> _connectWebSocket() async {
    if (_isDisposed || _watchedAddress == null) return;

    await _disconnectWebSocket();

    try {
      final wsUrl = SolanaConfig.activeWebSocketUrl;
      debugPrint('Helius Watcher: Connecting to WebSocket: $wsUrl');

      _webSocket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 10),
      );

      isListeningNotifier.value = true;
      _reconnectAttempts = 0;

      // Keep the websocket alive without waking the device unnecessarily.
      _startPingTimer();

      // Subscribe to account changes with JSON parsed encoding and confirmed commitment
      final subscribePayload = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'accountSubscribe',
        'params': [
          _watchedAddress,
          {
            'encoding': 'jsonParsed',
            'commitment': 'confirmed',
          }
        ]
      });

      _webSocket!.add(subscribePayload);

      _wsSubscription = _webSocket!.listen(
        (data) => _onWebSocketMessage(data),
        onError: (err) {
          debugPrint('Helius Watcher: WebSocket error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('Helius Watcher: WebSocket connection closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Helius Watcher: Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_webSocket != null && !_isDisposed) {
        try {
          _webSocket!.add(jsonEncode({
            'jsonrpc': '2.0',
            'id': 999,
            'method': 'getHealth',
          }));
        } catch (_) {}
      }
    });
  }

  void _onWebSocketMessage(dynamic data) {
    try {
      final text = data is String ? data : utf8.decode(data as List<int>);
      final decoded = jsonDecode(text);

      if (decoded is! Map<String, dynamic>) return;

      // Check if it's an account notification
      if (decoded['method'] == 'accountNotification') {
        final params = decoded['params'];
        if (params is Map<String, dynamic>) {
          final result = params['result'];
          if (result is Map<String, dynamic>) {
            final value = result['value'];
            if (value is Map<String, dynamic> && value['lamports'] != null) {
              final raw = value['lamports'];
              if (raw is num) {
                _handleLamportUpdate(raw.toInt());
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Helius Watcher: Message parsing error: $e');
    }
  }

  /// Checks if we're in a send-cooldown window and the apparent "increase" is
  /// actually a stale RPC response bouncing back to the pre-send balance
  bool _isFalsePositiveFromSend(int newLamports) {
    if (_preSendLamports == null || _lastSendTime == null) return false;
    final elapsed = DateTime.now().difference(_lastSendTime!);
    if (elapsed > _sendCooldown) {
      // Cooldown expired, clear state
      _preSendLamports = null;
      _lastSendTime = null;
      return false;
    }
    // If the "new" balance is at or below the pre-send level,
    // it's a stale RPC response, not a real incoming fund
    if (newLamports <= _preSendLamports!) {
      debugPrint(
          'Helius Watcher: Suppressed false positive (stale RPC during send cooldown)');
      return true;
    }
    return false;
  }

  void _handleLamportUpdate(int newLamports) {
    if (!_hasBaselineBeenSet) {
      final old = _lastKnownLamports ?? 0;
      _lastKnownLamports = newLamports;
      _hasBaselineBeenSet = true;
      debugPrint(
          'Helius Watcher: Baseline established at ${newLamports / lamportsPerSol} SOL');

      // If balance increased from initial known state, trigger immediate alert
      if (newLamports > old && !_isFalsePositiveFromSend(newLamports)) {
        final delta = newLamports - old;
        final amtSol = delta / lamportsPerSol;
        debugPrint(
            '⚡ Helius Alert: Incoming fund detected on initial sync: +$amtSol SOL');
        _triggerReceivedFund(amtSol);
      }
      return;
    }

    final oldLamports = _lastKnownLamports ?? 0;

    if (newLamports > oldLamports) {
      // Check if this is a false positive from a stale RPC response after send
      if (_isFalsePositiveFromSend(newLamports)) {
        // Don't update lastKnownLamports — keep the post-send value
        return;
      }
      _lastKnownLamports = newLamports;
      final delta = newLamports - oldLamports;
      final amtSol = delta / lamportsPerSol;
      debugPrint('⚡ Helius Alert: Incoming fund detected: +$amtSol SOL');
      _triggerReceivedFund(amtSol);
    } else if (newLamports < oldLamports) {
      // Balance decreased (user sent funds) — record for cooldown protection
      _lastKnownLamports = newLamports;
      _preSendLamports = oldLamports;
      _lastSendTime = DateTime.now();
      debugPrint(
          'Helius Watcher: Balance decreased (send detected), cooldown active');
    } else {
      _lastKnownLamports = newLamports;
    }
  }

  /// Immediately triggers notification, chime, and haptic feedback without waiting for slow RPC lookups
  void _triggerReceivedFund(double amtSol) {
    const notificationId = AptoNotificationService.defaultFundNotificationId;

    // 1. Audio chime from assets
    AptoAudioService.playNotification();

    // 2. Haptic feedback
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    // 3. Instant native push notification in Android status bar & notification drawer
    AptoNotificationService.instance.showReceivedFundNotification(
      amountSol: amtSol,
      sender: 'Solana Devnet',
      signature: '',
      notificationId: notificationId,
    );

    // 4. Refresh wallet balance and activity on UI
    WalletAdapterService.instance.refreshBalance();

    // 5. Asynchronously look up sender & signature with tight timeout to enrich notification
    unawaited(_lookupTxDetailsAndEnrichNotification(amtSol, notificationId));
  }

  Future<void> _lookupTxDetailsAndEnrichNotification(
      double amtSol, int notificationId) async {
    final address = _watchedAddress;
    if (address == null || address.isEmpty) return;

    try {
      final client = SolanaClient(
        rpcUrl: Uri.parse(SolanaConfig.activeRpcUrl),
        websocketUrl: Uri.parse(SolanaConfig.activeWebSocketUrl),
      );

      final sigs = await client.rpcClient
          .getSignaturesForAddress(address, limit: 1)
          .timeout(const Duration(seconds: 3));

      if (sigs.isEmpty) return;

      final signature = sigs.first.signature;
      String sender = 'Counterparty';

      try {
        final tx = await client.rpcClient
            .getTransaction(signature)
            .timeout(const Duration(seconds: 3));

        if (tx != null) {
          final dynamic txObj = tx.transaction;
          final dynamic msg = txObj?.message;
          final dynamic keys = msg?.accountKeys;
          if (keys is List && keys.isNotEmpty) {
            final firstKey = _extractPubkey(keys[0]);
            sender = (firstKey == address && keys.length > 1)
                ? _extractPubkey(keys[1])
                : firstKey;
          }
        }
      } catch (_) {}

      // Update notification with enriched counterparty details
      AptoNotificationService.instance.showReceivedFundNotification(
        amountSol: amtSol,
        sender: sender,
        signature: signature,
        notificationId: notificationId,
      );
    } catch (e) {
      debugPrint('Helius Watcher: Enrichment note: $e');
    }
  }

  String _extractPubkey(dynamic keyObj) {
    if (keyObj == null) return '';
    if (keyObj is String) return keyObj;
    try {
      final pub = (keyObj as dynamic).pubkey;
      if (pub != null) return pub.toString();
    } catch (_) {}
    return keyObj.toString();
  }

  void _scheduleReconnect() {
    isListeningNotifier.value = false;
    _pingTimer?.cancel();
    if (_isDisposed || _watchedAddress == null) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 3).clamp(2, 20);

    debugPrint(
        'Helius Watcher: Scheduling reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _watchedAddress != null) {
        _connectWebSocket();
      }
    });
  }

  /// Low-frequency safety poller used only while the websocket is unavailable.
  void _startFallbackPoller() {
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_isDisposed || _watchedAddress == null) return;
      if (isListeningNotifier.value && _webSocket != null) return;
      try {
        final client = SolanaClient(
          rpcUrl: Uri.parse(SolanaConfig.activeRpcUrl),
          websocketUrl: Uri.parse(SolanaConfig.activeWebSocketUrl),
        );
        final bal = await client.rpcClient
            .getBalance(_watchedAddress!)
            .timeout(const Duration(seconds: 5));
        _handleLamportUpdate(bal.value);
      } catch (_) {}
    });
  }

  Future<void> _disconnectWebSocket() async {
    isListeningNotifier.value = false;
    _pingTimer?.cancel();
    try {
      await _wsSubscription?.cancel();
      _wsSubscription = null;
      await _webSocket?.close();
      _webSocket = null;
    } catch (_) {}
  }

  /// Tests latency to Helius RPC and returns latency in ms
  Future<int> testRpcLatency() async {
    final sw = Stopwatch()..start();
    try {
      final client = SolanaClient(
        rpcUrl: Uri.parse(SolanaConfig.activeRpcUrl),
        websocketUrl: Uri.parse(SolanaConfig.activeWebSocketUrl),
      );
      await client.rpcClient.getLatestBlockhash();
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (e) {
      sw.stop();
      return -1;
    }
  }
}
