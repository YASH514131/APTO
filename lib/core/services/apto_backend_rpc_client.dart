import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:solana/solana.dart';

/// Authenticated access to the Render Solana RPC proxy.
class AptoBackendRpcClient {
  static const String baseUrl = 'https://apto-backend.onrender.com';
  static const String rpcPath = '/solana/rpc';
  static const Duration _budgetWindow = Duration(minutes: 15);
  static const Duration _minimumRequestSpacing = Duration(milliseconds: 250);
  static const int _maxRequestsPerWindow = 85;

  static final List<DateTime> _requestStartTimes = [];
  static Future<void> _scheduler = Future<void>.value();
  static DateTime? _lastRequestStart;

  static Map<String, String> get headers {
    final appApiKey = dotenv.env['APP_API_KEY']?.trim() ?? '';
    if (appApiKey.isEmpty) return const {};
    return <String, String>{
      // The currently deployed Render middleware expects the legacy raw key.
      // Change this to `Bearer $appApiKey` after AUTH_SCHEME=Bearer is deployed.
      'Authorization': appApiKey,
    };
  }

  static RpcClient create() {
    return RpcClient(
      '$baseUrl$rpcPath',
      customHeaders: headers,
    );
  }

  /// Starts requests at a controlled rate and keeps a rolling-window budget
  /// below the backend's 100 requests per 15 minutes limit.
  static Future<T> run<T>(Future<T> Function() request) {
    final completer = Completer<T>();
    _scheduler = _scheduler.then((_) async {
      while (true) {
        final now = DateTime.now();
        _requestStartTimes.removeWhere(
          (startedAt) => now.difference(startedAt) >= _budgetWindow,
        );

        var wait = Duration.zero;
        if (_requestStartTimes.length >= _maxRequestsPerWindow) {
          wait = _requestStartTimes.first.add(_budgetWindow).difference(now);
        }

        final lastStart = _lastRequestStart;
        if (lastStart != null) {
          final spacingWait =
              lastStart.add(_minimumRequestSpacing).difference(now);
          if (spacingWait > wait) wait = spacingWait;
        }

        if (wait <= Duration.zero) break;
        await Future<void>.delayed(wait);
      }

      final startedAt = DateTime.now();
      _requestStartTimes.add(startedAt);
      _lastRequestStart = startedAt;
      Future<T>.sync(request).then(
        completer.complete,
        onError: completer.completeError,
      );
    });
    return completer.future;
  }
}
