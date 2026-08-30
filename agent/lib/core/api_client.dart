import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  ApiException(this.status, this.code, this.message);

  @override
  String toString() => message;
}

class AgentRegistration {
  final String deviceId;
  final String deviceToken;
  final String name;

  AgentRegistration({required this.deviceId, required this.deviceToken, required this.name});

  factory AgentRegistration.fromJson(Map<String, dynamic> json) => AgentRegistration(
        deviceId: (json['device'] as Map<String, dynamic>)['id'] as String,
        deviceToken: json['deviceToken'] as String,
        name: (json['device'] as Map<String, dynamic>)['name'] as String,
      );
}

/// REST client for the agent. The agent self-registers without a user account.
class AgentApiClient {
  Future<Map<String, dynamic>> _call(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    try {
      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      final decoded = res.body.isEmpty ? <String, dynamic>{} : (jsonDecode(res.body) as Map<String, dynamic>);
      if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
      throw ApiException(
        res.statusCode,
        (decoded['error'] as String?) ?? 'error',
        (decoded['message'] as String?) ?? 'Request failed.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'network', 'Could not reach the server. Check your connection and server URL.');
    }
  }

  /// Registers (or re-registers) this agent device on the server.
  Future<AgentRegistration> registerAgent({
    String? deviceId,
    String? name,
    String? model,
    String? androidVersion,
    String? appVersion,
  }) async {
    final json = await _call('/devices/agent/register', {
      'deviceId': ?deviceId,
      'name': ?name,
      'model': ?model,
      'androidVersion': ?androidVersion,
      'appVersion': ?appVersion,
    });
    return AgentRegistration.fromJson(json);
  }
}

/// Collects basic device metadata for registration.
class DeviceInfoService {
  Future<({String model, String androidVersion, String appVersion})> gather() async {
    var model = 'Unknown Device';
    var androidVersion = 'Unknown';

    try {
      final deviceInfo = DeviceInfoPlugin();
      final android = await deviceInfo.androidInfo;
      model = android.model;
      androidVersion = android.version.release;
    } catch (_) {}

    return (model: model, androidVersion: androidVersion, appVersion: AppConfig.appVersion);
  }
}
