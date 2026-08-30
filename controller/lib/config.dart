/// App-wide configuration. Override via --dart-define at build time:
///   flutter build apk --dart-define=RMODZ_SERVER_URL=https://your-server
class AppConfig {
  AppConfig._();

  static const String serverUrl = String.fromEnvironment(
    'RMODZ_SERVER_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String _base = serverUrl;

  static String get baseUrl => _base;

  /// For WebSocket. Build a `ws://` / `wss://` URL from the HTTP base.
  static String get wsUrl {
    if (_base.startsWith('https://')) {
      return '${_base.replaceFirst('https://', 'wss://')}/ws';
    }
    if (_base.startsWith('http://')) {
      return '${_base.replaceFirst('http://', 'ws://')}/ws';
    }
    return '$_base/ws';
  }

  static String api(String path) => '$_base/api$path';
}
