import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the agent's device identity and session state.
class AgentSessionStore {
  static const _kDeviceId = 'device_id';
  static const _kDeviceName = 'device_name';
  static const _kDeviceToken = 'device_token';
  static const _kRegistered = 'registered';
  static const _kActiveSessionId = 'active_session_id';
  static const _kActiveSessionToken = 'active_session_token';

  final SharedPreferences _prefs;
  AgentSessionStore(this._prefs);

  static Future<AgentSessionStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AgentSessionStore(prefs);
  }

  String? get deviceId => _prefs.getString(_kDeviceId);
  String? get deviceName => _prefs.getString(_kDeviceName);
  String? get deviceToken => _prefs.getString(_kDeviceToken);
  bool get isRegistered => _prefs.getBool(_kRegistered) ?? false;
  String? get activeSessionId => _prefs.getString(_kActiveSessionId);
  String? get activeSessionToken => _prefs.getString(_kActiveSessionToken);

  Future<void> saveIdentity({
    required String deviceId,
    required String deviceToken,
    String? deviceName,
  }) async {
    await _prefs.setString(_kDeviceId, deviceId);
    await _prefs.setString(_kDeviceToken, deviceToken);
    if (deviceName != null) await _prefs.setString(_kDeviceName, deviceName);
    await _prefs.setBool(_kRegistered, true);
  }

  Future<void> saveActiveSession({required String sessionId, required String sessionToken}) async {
    await _prefs.setString(_kActiveSessionId, sessionId);
    await _prefs.setString(_kActiveSessionToken, sessionToken);
  }

  Future<void> clearActiveSession() async {
    await _prefs.remove(_kActiveSessionId);
    await _prefs.remove(_kActiveSessionToken);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }

  /// Generates a stable local device id (RMDZ-XXXXXX) when none exists yet.
  static String generateDeviceId() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final sb = StringBuffer('RMDZ-');
    for (var i = 0; i < 6; i++) {
      sb.write(alphabet[(rand >> (i * 4)) % alphabet.length]);
    }
    return sb.toString();
  }

  Map<String, dynamic> toMap() => {'deviceId': deviceId, 'deviceName': deviceName, 'registered': isRegistered};

  String toJson() => jsonEncode(toMap());
}
