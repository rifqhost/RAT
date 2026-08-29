import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show RTCDataChannel, RTCDataChannelState;
import 'controller_state.dart' show ControllerState;
import 'protocol.dart' show Protocol, WsEnvelope;

/// Controller-side outbound file transfer. Bytes travel over the WebRTC
/// 'file' data channel; metadata and progress use the signaling channel.
class FileTransferService {
  static const chunkSize = 64 * 1024;

  final ControllerState controller;
  final List<TransferProgress> active = [];
  final List<TransferProgress> finished = [];
  final _notify = StreamController<void>.broadcast();
  Stream<void> get changes => _notify.stream;

  FileTransferService(this.controller) {
    controller.ws?.addHandler(_onWs);
  }

  void refreshHandler() {
    controller.ws?.addHandler(_onWs);
  }

  void _emit() => _notify.add(null);

  void _onWs(WsEnvelope env) {
    if (env.type == 'FILE_ACCEPT') {
      final p = env.payload as Map<String, dynamic>;
      final id = p['transferId'] as String;
      final t = active.where((x) => x.id == id).toList();
      if (t.isNotEmpty) {
        t.first.status = TransferStatus.sending;
        _emit();
      }
    } else if (env.type == 'FILE_DECLINE') {
      final p = env.payload as Map<String, dynamic>;
      final id = p['transferId'] as String;
      final t = active.where((x) => x.id == id).toList();
      if (t.isNotEmpty) {
        t.first.status = TransferStatus.failed;
        t.first.error = (p['reason'] as String?) ?? 'Declined by agent';
        _emit();
      }
    }
  }

  Future<void> sendFile({required String path}) async {
    final file = File(path);
    if (!await file.exists()) return;
    final size = await file.length();
    if (size > 256 * 1024 * 1024) {
      return; // enforced size limit (send+enforced by agent too)
    }
    final name = file.uri.pathSegments.last;
    final mime = _mimeFromName(name);
    final digest = await sha256Of(path);
    final transfer = TransferProgress(
      id: _newId(),
      fileName: name,
      fileSize: size,
      mimeType: mime,
      sha256: digest,
      status: TransferStatus.requesting,
    );
    active.add(transfer);
    _emit();
    controller.sendFileRequest(
      transferId: transfer.id,
      fileName: name,
      fileSize: size,
      mimeType: mime,
      sha256: digest,
    );
    // start streaming once channel is open; the agent ack via FILE_ACCEPT
    _streamChunks(transfer, file);
  }

  Future<void> _streamChunks(TransferProgress t, File file) async {
    final dc = controller.rtc?.fileChannel;
    if (dc == null) return;
    // wait for data channel to open
    final opened = await _waitForChannel(dc, timeout: const Duration(seconds: 20));
    if (!opened || t.status == TransferStatus.cancelled) return;
    final raf = file.openSync();
    try {
      t.status = TransferStatus.sending;
      t.transferred = 0;
      _emit();
      while (t.transferred < t.fileSize) {
        final bytes = raf.readSync(min(chunkSize, t.fileSize - t.transferred));
        if (bytes.isEmpty) break;
        controller.rtc!.sendFileChunk(bytes);
        t.transferred += bytes.length;
        if (t.transferred % (chunkSize * 4) == 0 || t.transferred >= t.fileSize) {
          controller.ws?.send(Protocol.fileProgress(sessionId: controller.activeSessionId!, transferId: t.id, transferred: t.transferred));
          _emit();
        }
      }
      raf.closeSync();
      controller.ws?.send(Protocol.fileComplete(sessionId: controller.activeSessionId!, transferId: t.id, sha256: t.sha256));
      t.status = TransferStatus.complete;
    } catch (e) {
      t.status = TransferStatus.failed;
      t.error = e.toString();
    }
    _emit();
    if (t.status == TransferStatus.complete || t.status == TransferStatus.failed || t.status == TransferStatus.cancelled) {
      active.remove(t);
      finished.insert(0, t);
    }
  }

  Future<bool> _waitForChannel(RTCDataChannel channel, {Duration? timeout}) async {
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) return true;
    final completer = Completer<bool>();
    final sub = channel.stateChangeStream.listen((state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        completer.complete(true);
      }
    });
    if (timeout != null) {
      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(false);
      });
    }
    final r = await completer.future;
    sub.cancel();
    return r;
  }

  static Future<String> sha256Of(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  static String _mimeFromName(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg' || 'jpeg':
        return 'image/jpeg';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'apk':
        return 'application/vnd.android.package-archive';
      default:
        return 'application/octet-stream';
    }
  }

  static final _rand = Random();
  static String _newId() => 'tf${DateTime.now().millisecondsSinceEpoch}${_rand.nextInt(10000)}';
}

enum TransferStatus { requesting, sending, complete, failed, cancelled }

class TransferProgress {
  final String id;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String sha256;
  TransferStatus status;
  int transferred = 0;
  String? error;

  TransferProgress({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.sha256,
    required this.status,
  });

  double get fraction => fileSize == 0 ? 0 : (transferred / fileSize).clamp(0, 1);
}