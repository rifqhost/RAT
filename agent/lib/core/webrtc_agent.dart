import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'protocol.dart';
import 'ws_client.dart';

/// Agent-side WebRTC peer. The agent is the OFFERER and produces
/// screen/camera/mic tracks for the controller to consume.
///
/// Only tracks whose permission was granted are captured and added.
class WebRtcAgent {
  WebRtcAgent({required this.ws, required this.sessionId});

  final WsClient ws;
  final String sessionId;

  RTCPeerConnection? pc;
  RTCDataChannel? fileChannel;
  final List<MediaStream> _localStreams = [];
  MediaStreamTrack? _screenTrack;
  MediaStreamTrack? _cameraTrack;
  MediaStreamTrack? _micTrack;
  bool _initiated = false;

  final _connectionState = StreamController<RTCIceConnectionState>.broadcast();
  Stream<RTCIceConnectionState> get connectionState => _connectionState.stream;

  final _dcState = StreamController<bool>.broadcast();
  Stream<bool> get fileChannelState => _dcState.stream;

  Future<void> init({List<Map<String, dynamic>> iceServers = const []}) async {
    if (_initiated) return;
    _initiated = true;
    pc = await createPeerConnection({
      'iceServers': iceServers.map((s) => {
            'urls': s['urls'],
            if (s.containsKey('username')) 'username': s['username'],
            if (s.containsKey('credential')) 'credential': s['credential'],
          }).toList(),
      'sdpSemantics': 'unified-plan',
    });
    pc!.onIceCandidate = (candidate) {
      ws.send(Protocol.iceCandidate(sessionId: sessionId, candidate: {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }));
    };
    pc!.onIceConnectionState = (state) {
      _connectionState.add(state);
    };
  }

  /// Captures the screen via MediaProjection (native consent dialog) and adds
  /// it as a video track. Throws if the user denies capture.
  Future<void> addScreenShare() async {
    final stream = await navigator.mediaDevices.getDisplayMedia({
      'video': {
        'frameRate': {"ideal": 15, "max": 30},
        'width': {"ideal": 1280, "max": 1920},
        'height': {"ideal": 720, "max": 1080},
      },
      'audio': false,
    });
    _localStreams.add(stream);
    for (final track in stream.getTracks()) {
      if (track.kind == 'video') {
        _screenTrack = track;
        pc!.addTrack(track, stream);
      }
    }
  }

  void muteCamera() => _cameraTrack?.enabled = false;
  void unmuteCamera() => _cameraTrack?.enabled = true;
  void muteMicrophone() => _micTrack?.enabled = false;
  void unmuteMicrophone() => _micTrack?.enabled = true;

  Future<void> stopScreen() async {
    try {
      await _screenTrack?.stop();
    } catch (_) {}
    _screenTrack = null;
  }

  /// Adds the front/back camera as a video track.
  Future<void> addCamera({bool front = true}) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'facingMode': front ? 'user' : 'environment',
        'width': {"ideal": 1280},
        'height': {"ideal": 720},
      },
    });
    _localStreams.add(stream);
    for (final track in stream.getTracks()) {
      if (track.kind == 'video') {
        _cameraTrack = track;
        pc!.addTrack(track, stream);
      }
    }
  }

  /// Adds the microphone as an audio track.
  Future<void> addMicrophone() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    _localStreams.add(stream);
    for (final track in stream.getTracks()) {
      if (track.kind == 'audio') {
        _micTrack = track;
        pc!.addTrack(track, stream);
      }
    }
  }

  /// Creates the outbound 'file' data channel (controller sends files over it).
  Future<RTCDataChannel> createFileChannel() async {
    final channel = await pc!.createDataChannel('file', RTCDataChannelInit());
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _dcState.add(true);
      }
    };
    fileChannel = channel;
    return channel;
  }

  /// Creates an offer and sends it to the controller via the signaling server.
  Future<void> createAndSendOffer() async {
    final offer = await pc!.createOffer({'offerToReceiveVideo': false, 'offerToReceiveAudio': false});
    await pc!.setLocalDescription(offer);
    ws.send(Protocol.offer(sessionId: sessionId, sdp: offer.sdp!));
  }

  Future<void> handleAnswer(String sdp) async {
    await pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> addIce(Map<String, dynamic> candidateJson) async {
    await init();
    await pc!.addCandidate(RTCIceCandidate(
      candidateJson['candidate'],
      candidateJson['sdpMid'],
      candidateJson['sdpMLineIndex'],
    ));
  }

  Future<void> dispose() async {
    _connectionState.close();
    _dcState.close();
    for (final stream in _localStreams) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
    }
    _localStreams.clear();
    _screenTrack = null;
    _cameraTrack = null;
    _micTrack = null;
    try {
      await pc?.close();
    } catch (_) {}
    pc = null;
    fileChannel = null;
    _initiated = false;
  }
}
