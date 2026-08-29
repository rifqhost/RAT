import 'package:flutter_test/flutter_test.dart';
import 'package:rmodz_agent/core/file_receiver.dart';
import 'package:rmodz_agent/core/protocol.dart';

void main() {
  test('Protocol.auth builds a valid AUTH envelope', () {
    final env = Protocol.auth(deviceId: 'RMDZ-ABC123', role: 'agent', token: 'token', name: 'HP B');
    expect(env.type, 'AUTH');
    expect(env.payload['deviceId'], 'RMDZ-ABC123');
    expect(env.payload['role'], 'agent');
    expect(env.id, isNotEmpty);
  });

  test('sessionAccept carries granted permissions', () {
    final env = Protocol.sessionAccept(sessionId: 's1', permissions: ['SCREEN', 'TOUCH']);
    expect(env.type, 'SESSION_ACCEPT');
    expect(env.payload['permissions'], ['SCREEN', 'TOUCH']);
  });

  test('permission labels exist for all permissions', () {
    for (final perm in Permissions.all) {
      expect(Permissions.label(perm), isNotEmpty);
    }
  });

  test('envelope round-trips through json', () {
    final env = Protocol.permissionUpdate(sessionId: 's1', permission: 'CAMERA', granted: false);
    final decoded = WsEnvelope.fromJson(env.toJson());
    expect(decoded.type, 'PERMISSION_UPDATE');
    expect(decoded.payload['granted'], false);
  });

  test('file receiver sanitizes unsafe filenames', () {
    expect(FileReceiver.sanitizeName('a/b\\c:d*e?f"g<h>i|j.txt'), isNot(contains('/')));
    expect(FileReceiver.sanitizeName('a/b\\c:d*e?f"g<h>i|j.txt'), isNot(contains('\\')));
    expect(FileReceiver.sanitizeName('../secrets.txt'), isNot(contains('..')));
    expect(FileReceiver.sanitizeName(''), 'file.bin');
  });
}
