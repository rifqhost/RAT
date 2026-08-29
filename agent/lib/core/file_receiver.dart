import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCDataChannelMessage;
import 'package:path_provider/path_provider.dart';
import 'agent_state.dart' show AgentState;
import 'protocol.dart' show Protocol, WsEnvelope;

/// Agent-side inbound file transfer. Bytes arrive over the 'file' data channel;
/// metadata and progress use the signaling channel.
class FileReceiver {
  static const maxFileBytes = 256 * 1024 * 1024;

  final AgentState agent;
  final List<ReceiveProgress> active = [];
  final List<ReceiveProgress> finished = [];
  final _notify = StreamController<void>.broadcast();
  Stream<void> get changes => _notify.stream;

  String? _currentTransferId;
  IOSink? _sink;
  int _received = 0;
  bool _finished = false;

  FileReceiver(this.agent) {
    agent.ws?.addHandler(_onWs);
  }

  void refreshHandler() {
    agent.ws?.addHandler(_onWs);
  }

  void _emit() => _notify.add(null);

  /// Called by the WebRTC layer when the 'file' data channel receives a
  /// binary message (a file chunk from the controller).
  Future<void> onBinary(RTCDataChannelMessage message) async {
    if (!message.isBinary) return;
    final bytes = message.binary;
    if (_currentTransferId == null || _sink == null) return;
    _received += bytes.length;
    _sink!.add(bytes);
    if (_received >= _totalBytes && !_finished) {
      _finish();
    }
  }

  int _totalBytes = 0;

  void _onWs(WsEnvelope env) {
    final payload = env.payload is Map<String, dynamic> ? env.payload as Map<String, dynamic> : <String, dynamic>{};
    final type = env.type;
    if (type == 'FILE_REQUEST') {
      _onRequest(payload);
    } else if (type == 'FILE_PROGRESS') {
      final id = payload['transferId'] as String?;
      final t = active.where((x) => x.id == id).toList();
      if (t.isNotEmpty) {
        t.first.transferred = (payload['transferred'] as num?)?.toInt() ?? t.first.transferred;
        _emit();
      }
    } else if (type == 'FILE_COMPLETE') {
      final t = active.where((x) => x.id == payload['transferId']).toList();
      if (t.isNotEmpty) t.first.status = ReceiveStatus.complete;
      _emit();
    } else if (type == 'SESSION_ENDED' || type == 'DISCONNECT') {
      abortAll();
    }
  }

  Future<void> _onRequest(Map<String, dynamic> payload) async {
    final id = payload['transferId'] as String;
    final name = sanitizeName(payload['fileName'] as String? ?? 'file.bin');
    final size = (payload['fileSize'] as num?)?.toInt() ?? 0;
    final mime = payload['mimeType'] as String? ?? 'application/octet-stream';
    final sha = payload['sha256'] as String?;

    if (size > maxFileBytes) {
      agent.ws?.send(Protocol.fileDecline(sessionId: agent.activeSessionId!, transferId: id, reason: 'File too large'));
      return;
    }

    // Send acceptance, then open the destination file.
    agent.ws?.send(Protocol.fileAccept(sessionId: agent.activeSessionId!, transferId: id));
    final progress = ReceiveProgress(
      id: id,
      fileName: name,
      fileSize: size,
      mimeType: mime,
      sha256: sha ?? '',
      status: ReceiveStatus.receiving,
    );
    active.add(progress);
    _emit();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/downloads/$name');
      await file.parent.create(recursive: true);
      _sink = file.openWrite();
      _currentTransferId = id;
      _totalBytes = size;
      _received = 0;
      _finished = false;
    } catch (_) {
      agent.ws?.send(Protocol.fileDecline(sessionId: agent.activeSessionId!, transferId: id, reason: 'Cannot write file'));
      active.remove(progress);
      _emit();
    }
  }

  Future<void> _finish() async {
    _finished = true;
    final id = _currentTransferId;
    final sink = _sink;
    _sink = null;
    _currentTransferId = null;
    await sink?.flush();
    await sink?.close();
    final t = active.where((x) => x.id == id).toList();
    if (t.isNotEmpty) {
      t.first.status = ReceiveStatus.complete;
      t.first.transferred = _totalBytes;
      // verify checksum if provided
      if (t.first.sha256.isNotEmpty) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/downloads/${t.first.fileName}');
          final bytes = await file.readAsBytes();
          final digest = sha256.convert(bytes).toString();
          t.first.verified = digest.toLowerCase() == t.first.sha256.toLowerCase();
        } catch (_) {}
      }
      active.remove(t.first);
      finished.insert(0, t.first);
    }
    _emit();
  }

  /// Aborts all active transfers, closing any open sink.
  void abortAll() {
    _sink?.close();
    _sink = null;
    _currentTransferId = null;
    if (active.isNotEmpty) {
      active.forEach((t) => t.status = ReceiveStatus.cancelled);
      finished.insertAll(0, active);
      active.clear();
    }
    _emit();
  }

  static String sanitizeName(String name) {
    var cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    // strip leading dots to prevent parent-directory traversal
    cleaned = cleaned.replaceFirst(RegExp(r'^(\.\.)+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\.+'), '');
    return cleaned.isEmpty ? 'file.bin' : cleaned;
  }

  void dispose() {
    agent.ws?.removeHandler(_onWs);
    _notify.close();
    _sink?.close();
  }
}

enum ReceiveStatus { receiving, complete, cancelled }

class ReceiveProgress {
  final String id;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String sha256;
  ReceiveStatus status;
  int transferred = 0;
  bool verified = false;

  ReceiveProgress({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.sha256,
    required this.status,
  });

  double get fraction => fileSize == 0 ? 0 : (transferred / fileSize).clamp(0, 1);
}
