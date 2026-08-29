/// App-wide configuration. Override the server URL at build time:
///   flutter build apk --dart-define=RMODZ_SERVER_URL=https://your-server
library;

class AppConfig {
  /// Base URL of the RMODZ signaling server.
  static const String baseUrl = String.fromEnvironment(
    'RMODZ_SERVER_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// WebSocket URL derived from [baseUrl].
  static String get wsUrl {
    final https = baseUrl.startsWith('https://');
    final host = baseUrl.replaceFirst('https://', '').replaceFirst('http://', '');
    return '${https ? 'wss' : 'ws'}://$host/ws';
  }

  static const String appName = 'RMODZ Agent';
  static const String appVersion = '0.1.0';
  static const String deviceIdPrefix = 'RMDZ';
  static const String baseUrlDisplay = baseUrl;

  static const int wsConnectTimeout = 15000;
  static const int wsHeartbeatInterval = 20000;
  static const int wsReconnectBase = 1000;
  static const int wsReconnectMax = 15000;
}
