import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  ApiException(this.status, this.code, this.message);

  @override
  String toString() => message;
}

/// Thin REST client against the RMODZ server.
class ApiClient {
  ApiClient(this._token);

  String? _token;

  String? get token => _token;

  void setToken(String t) => _token = t;

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse(AppConfig.api(path));
    final headers = {
      'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };
    http.Response res;
    try {
      if (method == 'GET') {
        res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      } else {
        res = await http
            .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
            .timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      throw ApiException(0, 'network', 'Could not reach the server. Check your connection and server URL.');
    }
    final decoded = res.body.isEmpty ? <String, dynamic>{} : (jsonDecode(res.body) as Map<String, dynamic>);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    throw ApiException(
      res.statusCode,
      (decoded['error'] as String?) ?? 'error',
      (decoded['message'] as String?) ?? 'Request failed.',
    );
  }

  Future<LoginResult> register({required String name, required String email, required String password}) async {
    final json = await _call('POST', '/auth/register', body: {'name': name, 'email': email, 'password': password});
    return LoginResult.fromJson(json);
  }

  Future<LoginResult> login({required String email, required String password}) async {
    final json = await _call('POST', '/auth/login', body: {'email': email, 'password': password});
    return LoginResult.fromJson(json);
  }

  Future<RegisteredDevice> registerDevice({
    required String role,
    required String name,
    String? model,
    String? androidVersion,
    String? appVersion,
  }) async {
    final json = await _call(
      'POST',
      '/devices/register',
      body: {
        'role': role,
        'name': name,
        if (model != null) 'model': model,
        if (androidVersion != null) 'androidVersion': androidVersion,
        if (appVersion != null) 'appVersion': appVersion,
      },
      auth: true,
    );
    return RegisteredDevice.fromJson(json);
  }

  Future<List<Device>> getDevices() async {
    final json = await _call('GET', '/devices', auth: true);
    final list = (json['devices'] as List?) ?? [];
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PairingResult> pair({required String deviceId, required String code}) async {
    final json = await _call('POST', '/devices/pair', body: {'deviceId': deviceId, 'code': code}, auth: true);
    return PairingResult.fromJson(json);
  }

  Future<String> createSession({required String agentDeviceId, required List<String> permissions}) async {
    final json = await _call(
      'POST',
      '/sessions',
      body: {'agentDeviceId': agentDeviceId, 'permissions': permissions},
      auth: true,
    );
    return json['sessionId'] as String;
  }

  Future<List<SessionInfo>> getSessions() async {
    final json = await _call('GET', '/sessions', auth: true);
    final list = (json['sessions'] as List?) ?? [];
    return list.map((e) => SessionInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ActiveSessionResult?> getActiveSession() async {
    final json = await _call('GET', '/sessions/active', auth: true);
    final session = json['session'];
    if (session == null) return null;
    return ActiveSessionResult.fromJson(json);
  }

  Future<void> endSession(String sessionId) async {
    // DELETE endpoint
    final uri = Uri.parse(AppConfig.api('/sessions/$sessionId'));
    final response = await http
        .delete(uri, headers: {'Authorization': 'Bearer $_token'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'error', 'Failed to end session.');
    }
  }
}

class LoginResult {
  final String token;
  final String userId;
  final String name;
  final String email;

  LoginResult({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        token: json['token'] as String,
        userId: (json['user'] as Map<String, dynamic>)['id'] as String,
        name: (json['user'] as Map<String, dynamic>)['name'] as String,
        email: (json['user'] as Map<String, dynamic>)['email'] as String,
      );
}

class RegisteredDevice {
  final String id;
  final String role;
  final String name;
  final String deviceToken;

  RegisteredDevice({
    required this.id,
    required this.role,
    required this.name,
    required this.deviceToken,
  });

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) => RegisteredDevice(
        id: (json['device'] as Map<String, dynamic>)['id'] as String,
        role: (json['device'] as Map<String, dynamic>)['role'] as String,
        name: (json['device'] as Map<String, dynamic>)['name'] as String,
        deviceToken: json['deviceToken'] as String,
      );
}

class ActiveSessionResult {
  final SessionInfo? session;
  final String? sessionToken;

  ActiveSessionResult({this.session, this.sessionToken});

  factory ActiveSessionResult.fromJson(Map<String, dynamic> json) => ActiveSessionResult(
        session: json['session'] != null ? SessionInfo.fromJson(json['session'] as Map<String, dynamic>) : null,
        sessionToken: json['sessionToken'] as String?,
      );
}
