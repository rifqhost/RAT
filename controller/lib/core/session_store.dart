import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the signed-in controller profile + registered device locally.
class SessionStore {
  static const _kAuthToken = 'auth_token';
  static const _kUserJson = 'user_json';
  static const _kDeviceId = 'device_id';
  static const _kDeviceToken = 'device_token';
  static const _kDeviceName = 'device_name';

  static Future<AppSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString(_kAuthToken);
    if (authToken == null) return null;
    final userJson = prefs.getString(_kUserJson);
    return AppSession(
      authToken: authToken,
      user: userJson != null ? (jsonDecode(userJson) as Map<String, dynamic>) : null,
      deviceId: prefs.getString(_kDeviceId),
      deviceToken: prefs.getString(_kDeviceToken),
      deviceName: prefs.getString(_kDeviceName),
    );
  }

  static Future<void> save(AppSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthToken, session.authToken);
    if (session.user != null) await prefs.setString(_kUserJson, jsonEncode(session.user));
    if (session.deviceId != null) await prefs.setString(_kDeviceId, session.deviceId!);
    if (session.deviceToken != null) await prefs.setString(_kDeviceToken, session.deviceToken!);
    if (session.deviceName != null) await prefs.setString(_kDeviceName, session.deviceName!);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthToken);
    await prefs.remove(_kUserJson);
    await prefs.remove(_kDeviceId);
    await prefs.remove(_kDeviceToken);
    await prefs.remove(_kDeviceName);
  }
}

class AppSession {
  final String authToken;
  final Map<String, dynamic>? user;
  final String? deviceId;
  final String? deviceToken;
  final String? deviceName;

  AppSession({
    required this.authToken,
    this.user,
    this.deviceId,
    this.deviceToken,
    this.deviceName,
  });
}
