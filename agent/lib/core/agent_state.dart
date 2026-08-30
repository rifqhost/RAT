import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart' show AgentApiClient, DeviceInfoService;
import 'file_receiver.dart';
import 'native_bridge.dart';
import 'protocol.dart';
import 'session_store.dart';
import 'webrtc_agent.dart';
import 'ws_client.dart';

enum AgentStage { loading, needsIdentity, registered, pairing, session }

/// Central state machine for the Agent app.
class AgentState extends ChangeNotifier {
  AgentState(this.store);

  final AgentSessionStore store;
  final AgentApiClient api = AgentApiClient();
  final DeviceInfoService deviceInfo = DeviceInfoService();

  AgentStage stage = AgentStage.loading;
  String? error;
  String? deviceId;
  String? deviceName;
  String? deviceToken;
  bool wsConnected = false;
  String? pairingCode;
  int? pairingExpiresIn;
  String? activeSessionId;
  List<String> permissions = [];
  bool sessionActive = false;

  WsClient? ws;
  WebRtcAgent? rtc;
  FileReceiver? receiver;

  // pending dialogs surfaced to the UI
  PendingPair? pendingPair;
  PendingSession? pendingSession;

  final String _defaultName = 'RMODZ Agent';
  List<Map<String, dynamic>> _iceServers = [];

  Future<void> bootstrap() async {
    stage = AgentStage.loading;
    notifyListeners();
    try {
      deviceId = store.deviceId;
      if (!store.isRegistered || deviceId == null) {
        await _registerNewIdentity();
      } else {
        deviceToken = store.deviceToken;
        deviceName = store.deviceName;
      }
      stage = AgentStage.registered;
      notifyListeners();
      await _connectWebSocket();
    } catch (e) {
      error = e.toString();
      stage = AgentStage.needsIdentity;
      notifyListeners();
    }
  }

  Future<void> _registerNewIdentity() async {
    final id = store.deviceId ?? AgentSessionStore.generateDeviceId();
    final info = await deviceInfo.gather();
    final reg = await api.registerAgent(
      deviceId: id,
      name: _defaultName,
      model: info.model,
      androidVersion: info.androidVersion,
      appVersion: info.appVersion,
    );
    deviceId = reg.deviceId;
    deviceToken = reg.deviceToken;
    deviceName = reg.name;
    await store.saveIdentity(deviceId: reg.deviceId, deviceToken: reg.deviceToken, deviceName: reg.name);
  }

  Future<void> _connectWebSocket() async {
    final ws = WsClient(deviceId: deviceId!, role: 'agent', deviceToken: deviceToken!);
    ws.setDisplayName(deviceName ?? _defaultName);
    this.ws = ws;
    ws.addHandler(_onWs);
    receiver = FileReceiver(this);
    ws.stateStream.listen((state) {
      wsConnected = state == WsState.connected;
      notifyListeners();
    });
    await ws.connect();
  }

  // ------------------------------------------------------------- signaling
  bool get canPair => wsConnected;

  Future<void> requestPairingCode() async {
    final ws = this.ws;
    if (ws == null) return;
    final responseFuture = ws.next('PAIR_RESPONSE', timeout: const Duration(seconds: 10));
    ws.send(Protocol.pairRequest(deviceId: deviceId!));
    final response = await responseFuture;
    final payload = response.payload is Map<String, dynamic> ? response.payload as Map<String, dynamic> : <String, dynamic>{};
    pairingCode = payload['code'] as String?;
    pairingExpiresIn = (payload['expiresIn'] as num?)?.toInt();
    stage = AgentStage.pairing;
    notifyListeners();
  }

  void approvePair() {
    final pair = pendingPair;
    if (pair == null) return;
    ws?.send(Protocol.pairApproved(pairId: pair.pairId));
    pendingPair = null;
    notifyListeners();
  }

  void denyPair() {
    final pair = pendingPair;
    if (pair == null) return;
    ws?.send(Protocol.pairDenied(pairId: pair.pairId));
    pendingPair = null;
    notifyListeners();
  }

  void acceptSession({List<String> granted = const []}) {
    final session = pendingSession;
    if (session == null) return;
    ws?.send(Protocol.sessionAccept(sessionId: session.sessionId, permissions: granted));
    pendingSession = null;
    activeSessionId = session.sessionId;
    permissions = granted;
    notifyListeners();
    _startOffererFlow(session.sessionId, granted);
  }

  void denySession({String? reason}) {
    final session = pendingSession;
    if (session == null) return;
    ws?.send(Protocol.sessionDeny(sessionId: session.sessionId, reason: reason));
    pendingSession = null;
    notifyListeners();
  }

  void endSession({String? reason}) {
    final id = activeSessionId;
    if (id != null) ws?.send(Protocol.disconnect(sessionId: id, reason: reason));
    _cleanupSession();
  }

  void revokePermission(String permission) {
    final id = activeSessionId;
    if (id == null) return;
    final idx = permissions.indexOf(permission);
    if (idx < 0) return;
    permissions.removeAt(idx);
    ws?.send(Protocol.permissionUpdate(sessionId: id, permission: permission, granted: false));
    notifyListeners();
    _applyPermission(permission, false);
  }

  // ----------------------------------------------------------- message bus
  void _onWs(WsEnvelope env) {
    final payload = env.payload is Map<String, dynamic> ? env.payload as Map<String, dynamic> : <String, dynamic>{};
    switch (env.type) {
      case 'AUTH_OK':
        _onAuthOk(payload);
        break;
      case 'AUTH_ERROR':
      case 'ERROR':
        error = (payload['message'] as String?) ?? payload['code'] as String? ?? 'Error';
        notifyListeners();
        break;
      case 'PAIR_RESPONSE':
        pairingCode = payload['code'] as String?;
        pairingExpiresIn = (payload['expiresIn'] as num?)?.toInt();
        stage = AgentStage.pairing;
        notifyListeners();
        break;
      case 'PAIR_APPROVAL':
        pendingPair = PendingPair(
          pairId: payload['pairId'] as String,
          controllerName: (payload['controllerName'] as String?) ?? 'A controller',
          controllerDeviceId: payload['controllerDeviceId'] as String? ?? '',
        );
        notifyListeners();
        break;
      case 'SESSION_REQUEST':
        _iceServers = (payload['iceServers'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            [];
        pendingSession = PendingSession(
          sessionId: payload['sessionId'] as String,
          controllerName: (payload['controllerName'] as String?) ?? 'A controller',
          controllerDeviceId: payload['controllerDeviceId'] as String? ?? '',
          requestedPermissions: (payload['permissions'] as List?)?.cast<String>() ?? [],
        );
        notifyListeners();
        break;
      case 'SESSION_ACCEPTED':
        // handled on controller; agent flow starts immediately after SESSION_ACCEPT
        break;
      case 'SESSION_ENDED':
        _cleanupSession();
        notifyListeners();
        break;
      case 'ANSWER':
        rtc?.handleAnswer(payload['sdp'] as String);
        break;
      case 'ICE_CANDIDATE':
        rtc?.addIce((payload['candidate'] as Map?)?.cast<String, dynamic>() ?? {});
        break;
      case 'TOUCH_EVENT':
        if (permissions.contains('TOUCH')) _handleTouch(payload);
        break;
      case 'CONTROL_EVENT':
        _handleControl(payload);
        break;
      case 'CLIPBOARD_EVENT':
        if ((payload['direction'] as String?) == 'controller_to_agent' &&
            payload['text'] is String &&
            payload['text']!.isNotEmpty) {
          NativeBridge.setText(payload['text'] as String);
        }
        break;
      case 'PERMISSION_UPDATE': {
        final permission = payload['permission'] as String?;
        final granted = payload['granted'] as bool? ?? false;
        if (permission != null) {
          permissions.remove(permission);
          if (granted) permissions.add(permission);
          _applyPermission(permission, granted);
          notifyListeners();
        }
        break;
      }
      case 'HELLO':
      case 'PONG':
        break;
    }
  }

  void _onAuthOk(Map<String, dynamic> payload) {
    final rejoinId = payload['activeSessionId'] as String?;
    if (rejoinId != null && rejoinId.isNotEmpty) {
      activeSessionId = rejoinId;
      sessionActive = true;
      // restart the offerer flow for the rejoined session
      _startOffererFlow(rejoinId, permissionsWherePossible());
      notifyListeners();
    }
  }

  List<String> permissionsWherePossible() => permissions;

  void _handleTouch(Map<String, dynamic> payload) {
    final eventType = payload['eventType'] as String? ?? 'tap';
    final x = (payload['x'] as num?)?.toDouble() ?? 0.5;
    final y = (payload['y'] as num?)?.toDouble() ?? 0.5;
    final action = (payload['action'] as num?)?.toInt();
    var mapped = action;
    if (mapped == null) {
      switch (eventType) {
        case 'touch_down':
          mapped = 0; // ACTION_DOWN
          break;
        case 'touch_move':
          mapped = 2; // ACTION_MOVE
          break;
        case 'touch_up':
          mapped = 1; // ACTION_UP
          break;
        default:
          mapped = 1;
      }
    }
    NativeBridge.dispatchTouch(action: mapped, x: x, y: y);
  }

  void _handleControl(Map<String, dynamic> payload) {
    final kind = payload['kind'] as String? ?? '';
    if (kind == 'NAV_BACK') {
      NativeBridge.globalAction('BACK');
    } else if (kind == 'NAV_HOME') {
      NativeBridge.globalAction('HOME');
    } else if (kind == 'NAV_RECENTS') {
      NativeBridge.globalAction('RECENTS');
    } else if (kind == 'TEXT_INPUT') {
      NativeBridge.setText((payload['value'] as String?) ?? '');
    } else if (kind == 'CAMERA_OFF' && permissions.contains('CAMERA')) {
      rtc?.muteCamera();
    } else if (kind == 'CAMERA_ON' && permissions.contains('CAMERA')) {
      rtc?.unmuteCamera();
    } else if (kind == 'MIC_OFF' && permissions.contains('MICROPHONE')) {
      rtc?.muteMicrophone();
    } else if (kind == 'MIC_ON' && permissions.contains('MICROPHONE')) {
      rtc?.unmuteMicrophone();
    }
  }

  void _applyPermission(String permission, bool granted) {
    if (permission == 'CAMERA') {
      if (granted) {
        rtc?.unmuteCamera();
      } else {
        rtc?.muteCamera();
      }
    } else if (permission == 'MICROPHONE') {
      if (granted) {
        rtc?.unmuteMicrophone();
      } else {
        rtc?.muteMicrophone();
      }
    } else if (permission == 'SCREEN' && !granted) {
      rtc?.stopScreen();
    }
  }

  // --------------------------------------------------------- webrtc offerer
  Future<void> _startOffererFlow(String sessionId, List<String> granted) async {
    final ws = this.ws;
    if (ws == null) return;
    try {
      rtc?.dispose();
      rtc = WebRtcAgent(ws: ws, sessionId: sessionId);
      await rtc!.init(iceServers: _iceServers);
      if (granted.contains('SCREEN')) {
        try {
          await rtc!.addScreenShare();
        } catch (_) {
          // user denied screen capture; continue without it
        }
      }
      if (granted.contains('CAMERA')) {
        try {
          await rtc!.addCamera();
        } catch (_) {}
      }
      if (granted.contains('MICROPHONE')) {
        try {
          await rtc!.addMicrophone();
        } catch (_) {}
      }
      final fileChannel = await rtc!.createFileChannel();
      rtc!.fileChannelState.listen((open) {
        if (open) receiver?.refreshHandler();
      });
      fileChannel.onMessage = (message) {
        receiver?.onBinary(message);
      };
      await rtc!.createAndSendOffer();
      sessionActive = true;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void _cleanupSession() {
    rtc?.dispose();
    rtc = null;
    receiver!.abortAll();
    activeSessionId = null;
    permissions = [];
    sessionActive = false;
    store.clearActiveSession();
  }

  void setStage(AgentStage s) {
    stage = s;
    notifyListeners();
  }

  @override
  void dispose() {
    ws?.removeHandler(_onWs);
    ws?.dispose();
    rtc?.dispose();
    receiver?.dispose();
    super.dispose();
  }
}

class PendingPair {
  final String pairId;
  final String controllerName;
  final String controllerDeviceId;
  PendingPair({required this.pairId, required this.controllerName, required this.controllerDeviceId});
}

class PendingSession {
  final String sessionId;
  final String controllerName;
  final String controllerDeviceId;
  final List<String> requestedPermissions;
  PendingSession({
    required this.sessionId,
    required this.controllerName,
    required this.controllerDeviceId,
    required this.requestedPermissions,
  });
}
