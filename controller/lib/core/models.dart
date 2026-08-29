/// Data models used across the controller app.
class Device {
  final String id;
  final String name;
  final String? model;
  final String? androidVersion;
  final String? appVersion;
  final bool online;
  final DateTime? lastSeenAt;
  final String? pairId;

  Device({
    required this.id,
    required this.name,
    this.model,
    this.androidVersion,
    this.appVersion,
    required this.online,
    this.lastSeenAt,
    this.pairId,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? json['id'] as String,
        model: json['model'] as String?,
        androidVersion: json['androidVersion'] as String?,
        appVersion: json['appVersion'] as String?,
        online: json['online'] as bool? ?? false,
        lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt'] as String) : null,
        pairId: json['pairId'] as String?,
      );
}

class SessionInfo {
  final String id;
  final String status;
  final List<String> permissions;
  final DateTime? startedAt;

  SessionInfo({
    required this.id,
    required this.status,
    required this.permissions,
    this.startedAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        id: json['id'] as String,
        status: json['status'] as String,
        permissions: (json['permissions'] as List?)?.cast<String>() ?? [],
        startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      );
}

class IceServer {
  final String urls;
  final String? username;
  final String? credential;

  IceServer({required this.urls, this.username, this.credential});

  factory IceServer.fromJson(Map<String, dynamic> json) {
    final u = json['urls'];
    final urls = u is List ? (u.first as String) : (u as String);
    return IceServer(
      urls: urls,
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }
}

class PairingResult {
  final String pairId;
  final String status;
  final bool requiresApproval;

  PairingResult({
    required this.pairId,
    required this.status,
    required this.requiresApproval,
  });

  factory PairingResult.fromJson(Map<String, dynamic> json) => PairingResult(
        pairId: json['pairId'] as String,
        status: json['status'] as String,
        requiresApproval: json['requiresApproval'] as bool? ?? false,
      );
}

class SessionAcceptResult {
  final String sessionId;
  final List<String> permissions;
  final String sessionToken;
  final List<IceServer> iceServers;

  SessionAcceptResult({
    required this.sessionId,
    required this.permissions,
    required this.sessionToken,
    required this.iceServers,
  });

  factory SessionAcceptResult.fromJson(Map<String, dynamic> json) => SessionAcceptResult(
        sessionId: json['sessionId'] as String,
        permissions: (json['permissions'] as List?)?.cast<String>() ?? [],
        sessionToken: json['sessionToken'] as String,
        iceServers: (json['iceServers'] as List?)
                ?.map((e) => IceServer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
