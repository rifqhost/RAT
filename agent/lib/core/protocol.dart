/// Mirrors the server's signalling protocol (see server/src/protocol.ts).
/// Kept in sync manually with the agent app.
library;

/// Message envelope.
class WsEnvelope {
  final String id;
  final String type;
  final dynamic payload;
  final int ts;

  const WsEnvelope({required this.id, required this.type, required this.payload, required this.ts});

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'payload': payload, 'ts': ts};

  factory WsEnvelope.fromJson(Map<String, dynamic> json) => WsEnvelope(
        id: json['id'] as String,
        type: json['type'] as String,
        payload: json['payload'],
        ts: (json['ts'] as num?)?.toInt() ?? 0,
      );
}

/// Helper to build envelopes.
class Protocol {
  static String _uid() => DateTime.now().microsecondsSinceEpoch.toString() + (DateTime.now().millisecond).toString();

  static WsEnvelope auth({
    required String deviceId,
    required String role,
    required String token,
    String? name,
    String? model,
    String? androidVersion,
    String? appVersion,
    Map<String, dynamic>? rejoin,
  }) =>
      WsEnvelope(
        id: _uid(),
        type: 'AUTH',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'deviceId': deviceId,
          'role': role,
          'token': token,
          'name': ?name,
          'model': ?model,
          'androidVersion': ?androidVersion,
          'appVersion': ?appVersion,
          'rejoin': ?rejoin,
        },
      );

  static WsEnvelope pairRequest({required String deviceId}) => WsEnvelope(
        id: _uid(),
        type: 'PAIR_REQUEST',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'deviceId': deviceId},
      );

  static WsEnvelope pairApproved({required String pairId}) => WsEnvelope(
        id: _uid(),
        type: 'PAIR_APPROVED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'pairId': pairId},
      );

  static WsEnvelope pairDenied({required String pairId}) => WsEnvelope(
        id: _uid(),
        type: 'PAIR_DENIED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'pairId': pairId},
      );

  static WsEnvelope sessionAccept({required String sessionId, required List<String> permissions}) => WsEnvelope(
        id: _uid(),
        type: 'SESSION_ACCEPT',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'permissions': permissions},
      );

  static WsEnvelope sessionDeny({required String sessionId, String? reason}) => WsEnvelope(
        id: _uid(),
        type: 'SESSION_DENY',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'reason': ?reason},
      );

  static WsEnvelope sessionRejoin({required String sessionId, required String sessionToken}) => WsEnvelope(
        id: _uid(),
        type: 'SESSION_REJOIN',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'sessionToken': sessionToken},
      );

  static WsEnvelope offer({required String sessionId, required String sdp}) => WsEnvelope(
        id: _uid(),
        type: 'OFFER',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'sdp': sdp},
      );

  static WsEnvelope answer({required String sessionId, required String sdp}) => WsEnvelope(
        id: _uid(),
        type: 'ANSWER',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'sdp': sdp},
      );

  static WsEnvelope iceCandidate({required String sessionId, required Map<String, dynamic> candidate}) => WsEnvelope(
        id: _uid(),
        type: 'ICE_CANDIDATE',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'candidate': candidate},
      );

  static WsEnvelope touch({
    required String sessionId,
    required String eventType,
    required double x,
    required double y,
    required int screenWidth,
    required int screenHeight,
    int? action,
  }) =>
      WsEnvelope(
        id: _uid(),
        type: 'TOUCH_EVENT',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'sessionId': sessionId,
          'eventType': eventType,
          'x': x,
          'y': y,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'screenWidth': screenWidth,
          'screenHeight': screenHeight,
          'action': ?action,
        },
      );

  static WsEnvelope control({required String sessionId, required String kind, dynamic value}) => WsEnvelope(
        id: _uid(),
        type: 'CONTROL_EVENT',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'kind': kind, 'value': ?value},
      );

  static WsEnvelope fileRequest({
    required String sessionId,
    required String transferId,
    required String fileName,
    required int fileSize,
    required String mimeType,
    String? sha256,
    int? chunkSize,
  }) =>
      WsEnvelope(
        id: _uid(),
        type: 'FILE_REQUEST',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'sessionId': sessionId,
          'transferId': transferId,
          'fileName': fileName,
          'fileSize': fileSize,
          'mimeType': mimeType,
          'sha256': ?sha256,
          'chunkSize': ?chunkSize,
        },
      );

  static WsEnvelope fileAccept({required String sessionId, required String transferId}) => WsEnvelope(
        id: _uid(),
        type: 'FILE_ACCEPT',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'transferId': transferId},
      );

  static WsEnvelope fileDecline({required String sessionId, required String transferId, String? reason}) => WsEnvelope(
        id: _uid(),
        type: 'FILE_DECLINE',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'transferId': transferId, 'reason': ?reason},
      );

  static WsEnvelope fileProgress({required String sessionId, required String transferId, required int transferred}) => WsEnvelope(
        id: _uid(),
        type: 'FILE_PROGRESS',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'transferId': transferId, 'transferred': transferred},
      );

  static WsEnvelope fileComplete({required String sessionId, required String transferId, String? sha256}) => WsEnvelope(
        id: _uid(),
        type: 'FILE_COMPLETE',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'transferId': transferId, 'sha256': ?sha256},
      );

  static WsEnvelope clipboard({required String sessionId, required String direction, required String text}) => WsEnvelope(
        id: _uid(),
        type: 'CLIPBOARD_EVENT',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'direction': direction, 'text': text},
      );

  static WsEnvelope permissionUpdate({required String sessionId, required String permission, required bool granted}) => WsEnvelope(
        id: _uid(),
        type: 'PERMISSION_UPDATE',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'permission': permission, 'granted': granted},
      );

  static WsEnvelope disconnect({required String sessionId, String? reason}) => WsEnvelope(
        id: _uid(),
        type: 'DISCONNECT',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'sessionId': sessionId, 'reason': ?reason},
      );

  static WsEnvelope ping() => WsEnvelope(
        id: _uid(),
        type: 'PING',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'ts': DateTime.now().millisecondsSinceEpoch},
      );
}

/// Permission identifiers shared with the server.
class Permissions {
  static const List<String> all = [
    'SCREEN',
    'TOUCH',
    'CAMERA',
    'MICROPHONE',
    'FILES',
    'CLIPBOARD',
    'DEVICE_INFO',
  ];

  static const Map<String, String> labels = {
    'SCREEN': 'Screen',
    'TOUCH': 'Touch Control',
    'CAMERA': 'Camera',
    'MICROPHONE': 'Microphone',
    'FILES': 'File Transfer',
    'CLIPBOARD': 'Clipboard',
    'DEVICE_INFO': 'Device Info',
  };

  static String label(String p) => labels[p] ?? p;
}
