import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'models.dart';
import 'protocol.dart';
import 'ws_client.dart';

/// Controller-side WebRTC peer.
///
/// The Agent is the offerer (it produces screen/camera/mic tracks).
/// This peer answers and renders the incoming video.
class WebRtcController {
  WebRtcController({required this.ws, required this.sessionId});

  final WsClient ws;
  final String sessionId;

  RTCPeerConnection? pc;
  RTCVideoRenderer? renderer;
  RTCDataChannel? fileChannel;
  bool _initiated = false;

  Future<void> init({List<IceServer> iceServers = const []}) async {
    if (_initiated) return;
    _initiated = true;
    renderer = RTCVideoRenderer();
    await renderer!.initialize();
    pc = await createPeerConnection({
      'iceServers': iceServers.map((s) => {
            'urls': s.urls,
            if (s.username != null) 'username': s.username,
            if (s.credential != null) 'credential': s.credential,
          }).toList(),
      'sdpSemantics': 'unified-plan',
    });
    pc!.onTrack = (event) {
      if (event.track.kind == 'video') {
        renderer!.srcObject = event.streams.isNotEmpty ? event.streams.first : null;
      }
    };
    // The agent (offerer) creates the 'file' data channel; answerer receives it.
    pc!.onDataChannel = (channel) {
      if (channel.label == 'file') {
        fileChannel = channel;
        _dcState.add(true);
      }
    };
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

  final _connectionState = StreamController<RTCIceConnectionState>.broadcast();
  Stream<RTCIceConnectionState> get connectionState => _connectionState.stream;

  final _dcState = StreamController<bool>.broadcast();
  Stream<bool> get fileChannelState => _dcState.stream;

  /// Send bytes over the file data channel once open.
  Future<bool> sendFileChunk(Uint8List chunk) async {
    final dc = fileChannel;
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen) return false;
    await dc.send(RTCDataChannelMessage.fromBinary(chunk));
    return true;
  }

  /// Handle an incoming OFFER from the agent.
  Future<void> handleOffer(String sdp) async {
    await init();
    await pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await pc!.createAnswer();
    await pc!.setLocalDescription(answer);
    ws.send(Protocol.answer(sessionId: sessionId, sdp: answer.sdp!));
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
    try {
      await pc?.close();
    } catch (_) {}
    try {
      await renderer?.dispose();
    } catch (_) {}
    pc = null;
    renderer = null;
    fileChannel = null;
    _initiated = false;
  }
}
