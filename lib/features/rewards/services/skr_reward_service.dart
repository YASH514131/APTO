import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reward_history_item.dart';

/// Service responsible for communicating with the local SKR Reward backend.
///
/// Supports:
/// - Health check (`GET /health`)
/// - Fetch user reward balance (`GET /redeem/balance/{userPubkey}`)
/// - Confirm payment to accrue SKR (`POST /payment/confirm`)
/// - Redeem SKR rewards (`POST /redeem`)
/// - Live response logging for test observation
class SkrRewardService {
  static final SkrRewardService instance = SkrRewardService._internal();

  SkrRewardService._internal() {
    _loadSavedConfig();
  }

  static const String defaultDeployedUrl = 'https://apto-backend.onrender.com';
  static const String _prefsKey = 'skr_backend_base_url';
  static const String _prefsApiKey = 'skr_backend_app_api_key';
  static const String _prefsHistoryKey = 'skr_reward_history_items';

  final ValueNotifier<String> baseUrlNotifier =
      ValueNotifier<String>(defaultDeployedUrl);
  final ValueNotifier<String> apiKeyNotifier = ValueNotifier<String>('');

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<SkrLogEntry>> logsNotifier =
      ValueNotifier<List<SkrLogEntry>>([]);
  final ValueNotifier<List<RewardHistoryItem>> historyNotifier =
      ValueNotifier<List<RewardHistoryItem>>([]);

  Future<void> _loadSavedConfig() async {
    try {
      final envUrl = dotenv.env['SKR_BACKEND_URL'];
      final envKey = dotenv.env['APP_API_KEY'];

      if (envUrl != null && envUrl.trim().isNotEmpty) {
        baseUrlNotifier.value = envUrl.trim();
      }
      if (envKey != null && envKey.trim().isNotEmpty) {
        apiKeyNotifier.value = envKey.trim();
      }

      final prefs = await SharedPreferences.getInstance();
      if (baseUrlNotifier.value.isEmpty) {
        final savedUrl = prefs.getString(_prefsKey);
        if (savedUrl != null && savedUrl.trim().isNotEmpty) {
          baseUrlNotifier.value = savedUrl.trim();
        }
      }
      if (apiKeyNotifier.value.isEmpty) {
        final savedKey = prefs.getString(_prefsApiKey);
        if (savedKey != null && savedKey.trim().isNotEmpty) {
          apiKeyNotifier.value = savedKey.trim();
        }
      }

      final rawHistory = prefs.getStringList(_prefsHistoryKey);
      if (rawHistory != null && rawHistory.isNotEmpty) {
        historyNotifier.value = rawHistory
            .map((item) => RewardHistoryItem.fromJson(item))
            .where((item) => !item.id.startsWith('seed-'))
            .toList();
      } else {
        historyNotifier.value = [];
      }
    } catch (_) {}
  }

  Future<void> addHistoryRecord({
    required String title,
    required double amountSkr,
    required bool isCredit,
    String? tier,
    String? txSig,
  }) async {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final dateStr =
        '${months[now.month - 1]} ${now.day}, ${now.year} · $hour:$minute $ampm';

    final newItem = RewardHistoryItem(
      id: 'reward-${now.millisecondsSinceEpoch}',
      title: title,
      dateText: dateStr,
      amountSkr: amountSkr,
      isCredit: isCredit,
      tier: tier,
      txSig: txSig,
    );

    final current = List<RewardHistoryItem>.from(historyNotifier.value);
    current.insert(0, newItem);
    if (current.length > 50) {
      current.removeRange(50, current.length);
    }
    historyNotifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsHistoryKey,
        current.map((item) => item.toJson()).toList(),
      );
    } catch (_) {}
  }

  Future<void> setBaseUrl(String url) async {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    baseUrlNotifier.value = cleaned;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, cleaned);
    } catch (_) {}
  }

  Future<void> setApiKey(String key) async {
    final cleaned = key.trim();
    apiKeyNotifier.value = cleaned;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsApiKey, cleaned);
    } catch (_) {}
  }

  String get _currentBaseUrl {
    var url = baseUrlNotifier.value.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final key = apiKeyNotifier.value.trim();
    if (key.isNotEmpty) {
      headers['Authorization'] = key;
    }
    return headers;
  }

  void _addLog({
    required String method,
    required String endpoint,
    required int statusCode,
    required String responseBody,
    Map<String, dynamic>? requestPayload,
  }) {
    final entry = SkrLogEntry(
      timestamp: DateTime.now(),
      method: method,
      endpoint: endpoint,
      statusCode: statusCode,
      responseBody: responseBody,
      requestPayload: requestPayload,
    );
    final current = List<SkrLogEntry>.from(logsNotifier.value);
    current.insert(0, entry);
    if (current.length > 30) {
      current.removeRange(30, current.length);
    }
    logsNotifier.value = current;
  }

  /// Smoke test: GET /health
  Future<Map<String, dynamic>> checkHealth() async {
    final endpoint = '$_currentBaseUrl/health';
    try {
      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 45));
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final isOk = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (json['ok'] == true || json['status'] == 'ok');
      isConnectedNotifier.value = isOk;

      _addLog(
        method: 'GET',
        endpoint: '/health',
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      return json;
    } catch (e) {
      isConnectedNotifier.value = false;
      _addLog(
        method: 'GET',
        endpoint: '/health',
        statusCode: 0,
        responseBody: 'Error: $e',
      );
      rethrow;
    }
  }

  /// Balance inquiry: GET /redeem/balance/{userPubkey}
  Future<Map<String, dynamic>> getBalance(String userPubkey) async {
    final endpoint = '$_currentBaseUrl/redeem/balance/$userPubkey';
    try {
      final response = await http
          .get(Uri.parse(endpoint), headers: _headers)
          .timeout(const Duration(seconds: 45));

      _addLog(
        method: 'GET',
        endpoint: '/redeem/balance/$userPubkey',
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog(
        method: 'GET',
        endpoint: '/redeem/balance/$userPubkey',
        statusCode: 0,
        responseBody: 'Error: $e',
      );
      rethrow;
    }
  }

  /// Payment confirmation: POST /payment/confirm
  /// Payload: { "txSig": "...", "userPubkey": "...", "amountUsd": 20 }
  Future<Map<String, dynamic>> confirmPayment({
    required String txSig,
    required String userPubkey,
    required double amountUsd,
  }) async {
    final endpoint = '$_currentBaseUrl/payment/confirm';
    final payload = {
      'txSig': txSig,
      'userPubkey': userPubkey,
      'amountUsd': amountUsd,
    };

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));

      _addLog(
        method: 'POST',
        endpoint: '/payment/confirm',
        statusCode: response.statusCode,
        responseBody: response.body,
        requestPayload: payload,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog(
        method: 'POST',
        endpoint: '/payment/confirm',
        statusCode: 0,
        responseBody: 'Error: $e',
        requestPayload: payload,
      );
      rethrow;
    }
  }

  /// Redemption: POST /redeem
  /// Payload: { "userPubkey": "...", "amountSkr": 0.6 }
  Future<Map<String, dynamic>> redeem({
    required String userPubkey,
    required double amountSkr,
  }) async {
    final endpoint = '$_currentBaseUrl/redeem';
    final payload = {
      'userPubkey': userPubkey,
      'amountSkr': amountSkr,
    };

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));

      _addLog(
        method: 'POST',
        endpoint: '/redeem',
        statusCode: response.statusCode,
        responseBody: response.body,
        requestPayload: payload,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog(
        method: 'POST',
        endpoint: '/redeem',
        statusCode: 0,
        responseBody: 'Error: $e',
        requestPayload: payload,
      );
      rethrow;
    }
  }

  /// Treasury status: GET /treasury/status
  Future<Map<String, dynamic>> getTreasuryStatus() async {
    final endpoint = '$_currentBaseUrl/treasury/status';
    try {
      final response = await http
          .get(Uri.parse(endpoint), headers: _headers)
          .timeout(const Duration(seconds: 45));

      _addLog(
        method: 'GET',
        endpoint: '/treasury/status',
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog(
        method: 'GET',
        endpoint: '/treasury/status',
        statusCode: 0,
        responseBody: 'Error: $e',
      );
      rethrow;
    }
  }

  void clearLogs() {
    logsNotifier.value = [];
  }
}

class SkrLogEntry {
  final DateTime timestamp;
  final String method;
  final String endpoint;
  final int statusCode;
  final String responseBody;
  final Map<String, dynamic>? requestPayload;

  SkrLogEntry({
    required this.timestamp,
    required this.method,
    required this.endpoint,
    required this.statusCode,
    required this.responseBody,
    this.requestPayload,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
