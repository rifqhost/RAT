import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'session_store.dart';
import 'api_client.dart';
import 'models.dart';
import 'protocol.dart';
import 'ws_client.dart';
import 'webrtc_controller.dart';

enum ConnectStage { idle, pairing, waitingApproval, waitingAccept, connected, denied, error }

class ControllerState extends ChangeNotifier {
  ApiClient api = ApiClient(null);
  WsClient? ws;
  WebRtcController? rtc;
  AppSession? session;

  List<Device> devices = [];
  bool loadingDevices = false;

  ConnectStage stage = ConnectStage.idle;
  String? stageDetail;
  String? activeSessionId;
  List<String> sessionPermissions = [];
  List<IceServer> _iceServers = [];
  RTCVideoRenderer? remoteRenderer;

  bool sessionActive = false;
  DateTime? sessionStartedAt;

  bool get connected => ws?.state == WsState.connected;

  Future<void> bootstrap() async {
    session = await SessionStore.load();
    if (session != null) {
      api = ApiClient(session!.authToken);
      await connectWs();
      notifyListeners();
    }
  }

  Future<void> registerAndLogin({required String name, required String email, required String password, required String deviceName}) async {
    final reg = await api.register(name: name, email: email, password: password);
    await _finalizeLogin(reg, deviceName);
  }

  Future<void> login({required String email, required String password, required String deviceName}) async {
    final res = await api.login(email: email, password: password);
    await _finalizeLogin(res, deviceName);
  }

  Future<void> _finalizeLogin(LoginResult login, String deviceName) async {
    api = ApiClient(login.token);
    // Register the controller device (idempotent-ish; new each login for demo).
    final reg = await api.registerDevice(role: 'controller', name: deviceName);
    final appSession = AppSession(
      authToken: login.token,
      user: {'id': login.userId, 'name': login.name, 'email': login.email},
      deviceId: reg.id,
      deviceToken: reg.deviceToken,
      deviceName: deviceName,
    );
    await SessionStore.save(appSession);
    session = appSession;
    api = ApiClient(login.token);
    await connectWs();
    notifyListeners();
  }

  Future<void> connectWs() async {
    final s = session;
    if (s == null || s.deviceId == null || s.deviceToken == null) return;
    ws?.dispose();
    ws = WsClient(deviceId: s.deviceId!, role: 'controller', deviceToken: s.deviceToken!);
    ws!.setDisplayName(s.user?['name'] as String? ?? 'RMODZ Controller');
    ws!.addHandler(_onWsMessage);
    ws!.stateStream.listen((_) => notifyListeners());
    await ws!.connect();
    refreshDevices();
  }

  void _onWsMessage(WsEnvelope env) {
    switch (env.type) {
      case 'PAIR_APPROVED':
        stage = ConnectStage.waitingApproval;
        stageDetail = 'Pairing approved by agent.';
        notifyListeners();
        break;
      case 'PAIR_DENIED':
        stage = ConnectStage.error;
        stageDetail = 'The agent declined the pairing request.';
        notifyListeners();
        break;
      case 'SESSION_ACCEPTED':
        _onSessionAccepted(env);
        break;
      case 'SESSION_DENY':
        stage = ConnectStage.denied;
        stageDetail = (env.payload as Map<String, dynamic>)['reason'] as String? ?? 'The agent declined the session request.';
        notifyListeners();
        break;
      case 'SESSION_ENDED':
        _onSessionEnded(env);
        break;
      case 'OFFER':
        _handleOfferMessage(env);
        break;
      case 'ANSWER':
        _handleAnswerMessage(env);
        break;
      case 'ICE_CANDIDATE':
        _handleIceMessage(env);
        break;
      case 'PERMISSION_UPDATE':
        _applyPermissionUpdate(env);
        break;
      case 'ERROR':
        _handleError(env);
        break;
      default:
        break;
    }
  }

  // -------------------------------------------------------------- pairing

  Future<void> pairWith({required String deviceId, required String code}) async {
    stage = ConnectStage.waitingApproval;
    stageDetail = 'Waiting for agent approval...';
    notifyListeners();
    try {
      final result = await api.pair(deviceId: deviceId, code: code);
      if (!result.requiresApproval) {
        stage = ConnectStage.idle;
        notifyListeners();
      }
    } on ApiException catch (e) {
      stage = ConnectStage.error;
      stageDetail = e.message;
      notifyListeners();
    }
  }

  Future<void> requestSession(Device device, {List<String> permissions = const ['SCREEN', 'TOUCH', 'CAMERA', 'MICROPHONE', 'FILES', 'CLIPBOARD', 'DEVICE_INFO']}) async {
    stage = ConnectStage.waitingAccept;
    stageDetail = 'Waiting for ${device.name} to accept...';
    notifyListeners();
    try {
      activeSessionId = await api.createSession(agentDeviceId: device.id, permissions: permissions);
      sessionPermissions = permissions;
    } on ApiException catch (e) {
      stage = ConnectStage.error;
      stageDetail = e.message;
      notifyListeners();
    }
  }

  void _onSessionAccepted(WsEnvelope env) {
    final p = env.payload as Map<String, dynamic>;
    final result = SessionAcceptResult.fromJson(p);
    activeSessionId = result.sessionId;
    sessionPermissions = result.permissions;
    _iceServers = result.iceServers;
    sessionActive = true;
    sessionStartedAt = DateTime.now();
    stage = ConnectStage.connected;
    notifyListeners();
    _runWebRtc();
  }

  void _onSessionEnded(WsEnvelope env) {
    final p = env.payload as Map<String, dynamic>;
    sessionActive = false;
    // allow reconnect only if not manually revoked by user
    if (stage == ConnectStage.connected) {
      stage = ConnectStage.idle;
      stageDetail = 'Session ended: ${p['reason'] ?? 'closed'}';
    }
    activeSessionId = null;
    sessionPermissions = [];
    _disposeRtc();
    notifyListeners();
  }

  void _runWebRtc() {
    final sid = activeSessionId;
    final w = ws;
    if (sid == null || w == null) return;
    rtc = WebRtcController(ws: w, sessionId: sid);
    rtc!.connectionState.listen((state) {
      notifyListeners();
    });
    rtc!.init(iceServers: _iceServers);
    // Agent will send OFFER; handled by _handleOfferMessage.
  }

  Future<void> _handleOfferMessage(WsEnvelope env) async {
    final p = env.payload as Map<String, dynamic>;
    final sdp = p['sdp'] as String;
    await rtc!.handleOffer(sdp);
    remoteRenderer = rtc!.renderer;
    notifyListeners();
  }

  Future<void> _handleAnswerMessage(WsEnvelope env) async {
    final p = env.payload as Map<String, dynamic>;
    final sdp = p['sdp'] as String;
    await rtc!.handleAnswer(sdp);
  }

  Future<void> _handleIceMessage(WsEnvelope env) async {
    final p = env.payload as Map<String, dynamic>;
    await rtc!.addIce((p['candidate'] as Map).cast<String, dynamic>());
  }

  void _applyPermissionUpdate(WsEnvelope env) {
    final p = env.payload as Map<String, dynamic>;
    final perm = p['permission'] as String;
    final granted = p['granted'] as bool;
    final list = List<String>.from(sessionPermissions);
    if (granted && !list.contains(perm)) list.add(perm);
    if (!granted) list.remove(perm);
    sessionPermissions = list;
    notifyListeners();
  }

  void _handleError(WsEnvelope env) {
    final p = (env.payload as Map<String, dynamic>?) ?? {};
    stageDetail = (p['message'] as String?) ?? 'Something went wrong.';
    stage = ConnectStage.error;
    notifyListeners();
  }

  // ---------------------------------------------------------- input send

  void sendTouch({required String eventType, required double x, required double y, required int screenWidth, required int screenHeight, int? action}) {
    final sid = activeSessionId;
    final w = ws;
    if (sid == null || w == null) return;
    w.send(Protocol.touch(
      sessionId: sid,
      eventType: eventType,
      x: x,
      y: y,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      action: action,
    ));
  }

  void sendControl(String kind, [dynamic value]) {
    final sid = activeSessionId;
    final w = ws;
    if (sid == null || w == null) return;
    w.send(Protocol.control(sessionId: sid, kind: kind, value: value));
  }

  void sendClipboard(String text) {
    final sid = activeSessionId;
    final w = ws;
    if (sid == null || w == null) return;
    w.send(Protocol.clipboard(sessionId: sid, direction: 'controller_to_agent', text: text));
  }

  void sendFileRequest({required String transferId, required String fileName, required int fileSize, required String mimeType, String? sha256}) {
    final sid = activeSessionId;
    final w = ws;
    if (sid == null || w == null) return;
    w.send(Protocol.fileRequest(
      sessionId: sid,
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      sha256: sha256,
    ));
  }

  // ------------------------------------------------------------------ UI

  Future<void> refreshDevices() async {
    loadingDevices = true;
    notifyListeners();
    try {
      devices = await api.getDevices();
    } on ApiException {
      devices = [];
    }
    loadingDevices = false;
    notifyListeners();
  }

  Future<void> stopSession({String? reason}) async {
    final sid = activeSessionId;
    if (sid == null) return;
    ws?.send(Protocol.disconnect(sessionId: sid, reason: reason));
    try {
      await api.endSession(sid);
    } catch (_) {}
    _disposeRtc();
    sessionActive = false;
    stage = ConnectStage.idle;
    activeSessionId = null;
    sessionPermissions = [];
    notifyListeners();
  }

  Future<void> logout() async {
    // end active session
    if (activeSessionId != null) {
      await stopSession();
    }
    ws?.dispose();
    ws = null;
    _disposeRtc();
    await SessionStore.clear();
    session = null;
    devices = [];
    notifyListeners();
  }

  void _disposeRtc() {
    rtc?.dispose();
    rtc = null;
    remoteRenderer = null;
  }

  @override
  void dispose() {
    ws?.dispose();
    _disposeRtc();
    super.dispose();
  }
}
