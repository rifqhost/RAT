import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../config.dart';
import 'protocol.dart';

enum WsState { disconnected, connecting, connected }

/// Event bus for server messages the UI cares about.
typedef MessageHandler = void Function(WsEnvelope env);

/// Client WebSocket connection to the RMODZ signaling server.
class WsClient {
  WsClient({required this.deviceId, required this.role, required this.deviceToken});

  final String deviceId;
  final String role;
  final String deviceToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeat;
  Timer? _reconnect;
  bool _manualClose = false;
  int _reconnectAttempts = 0;

  WsState _state = WsState.disconnected;
  WsState get state => _state;

  final List<MessageHandler> _handlers = [];
  final Map<String, List<Completer<WsEnvelope>>> _wanted = {};

  void addHandler(MessageHandler h) => _handlers.add(h);
  void removeHandler(MessageHandler h) => _handlers.remove(h);

  /// Returns a future that resolves with the next message of [type].
  Future<WsEnvelope> next(String type, {Duration timeout = const Duration(seconds: 15)}) {
    final completer = Completer<WsEnvelope>();
    _wanted.putIfAbsent(type, () => []).add(completer);
    Timer(timeout, () {
      if (!completer.isCompleted) {
        _wanted[type]?.remove(completer);
        completer.completeError(TimeoutException('Timed out waiting for $type'));
      }
    });
    return completer.future;
  }

  Future<void> connect() async {
    _manualClose = false;
    _setState(WsState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      _sub = _channel!.stream.listen(
        (raw) => _onData(raw is String ? raw : utf8.decode(raw)),
        onDone: _onClosed,
        onError: (Object e) => _onClosed(),
      );
      await _authenticate();
      _startHeartbeat();
      _reconnectAttempts = 0;
    } catch (e) {
      _scheduleReconnect();
    }
  }

  Future<void> _authenticate() async {
    final env = Protocol.auth(
      deviceId: deviceId,
      role: role,
      token: deviceToken,
      name: _deviceName,
    );
    send(env);
  }

  String? _deviceName;

  void setDisplayName(String name) => _deviceName = name;

  Future<void> reconnectAfterFlip({required String sessionId, required String sessionToken}) async {
    _manualClose = false;
    _channel?.sink.close();
    _setState(WsState.connecting);
    final channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
    _channel = channel;
    _sub = channel.stream.listen(
      (raw) => _onData(raw is String ? raw : utf8.decode(raw)),
      onDone: _onClosed,
      onError: (Object e) => _onClosed(),
    );
    send(Protocol.sessionRejoin(sessionId: sessionId, sessionToken: sessionToken));
    _startHeartbeat();
  }

  void _onData(String raw) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final env = WsEnvelope.fromJson(json);
    if (env.type == 'PONG') return;
    if (env.type == 'AUTH_OK') {
      _setState(WsState.connected);
    } else if (env.type == 'AUTH_ERROR') {
      _setState(WsState.disconnected);
    }
    final wanted = _wanted.remove(env.type);
    if (wanted != null) {
      for (final c in wanted) {
        if (!c.isCompleted) c.complete(env);
      }
    }
    for (final h in List<MessageHandler>.from(_handlers)) {
      h(env);
    }
  }

  void _onClosed() {
    _heartbeat?.cancel();
    _setState(WsState.disconnected);
    if (!_manualClose) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manualClose) return;
    _reconnect?.cancel();
    final delay = Duration(seconds: [1, 2, 4, 8, 15][_reconnectAttempts.clamp(0, 4)]);
    _reconnectAttempts++;
    _reconnect = Timer(delay, () {
      if (!_manualClose) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      send(Protocol.ping());
    });
  }

  void send(WsEnvelope env) {
    _channel?.sink.add(jsonEncode(env.toJson()));
  }

  void close() {
    _manualClose = true;
    _heartbeat?.cancel();
    _reconnect?.cancel();
    _sub?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    _setState(WsState.disconnected);
  }

  void _setState(WsState s) {
    _state = s;
    _stateController.add(s);
  }

  final _stateController = StreamController<WsState>.broadcast();
  Stream<WsState> get stateStream => _stateController.stream;

  void dispose() {
    close();
    _stateController.close();
  }
}
