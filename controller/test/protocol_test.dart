import 'package:flutter_test/flutter_test.dart';
import 'package:rmodz_controller/core/protocol.dart';

void main() {
  test('Protocol.auth builds a valid AUTH envelope', () {
    final env = Protocol.auth(deviceId: 'RMDZ-ABC123', role: 'controller', token: 'token', name: 'HP A');
    expect(env.type, 'AUTH');
    expect(env.payload['deviceId'], 'RMDZ-ABC123');
    expect(env.payload['role'], 'controller');
    expect(env.payload['token'], 'token');
    expect(env.id, isNotEmpty);
  });

  test('touch event carries normalized coordinates and dimensions', () {
    final env = Protocol.touch(
      sessionId: 's1',
      eventType: 'tap',
      x: 0.5,
      y: 0.25,
      screenWidth: 1080,
      screenHeight: 2400,
    );
    expect(env.type, 'TOUCH_EVENT');
    expect(env.payload['x'], 0.5);
    expect(env.payload['y'], 0.25);
    expect(env.payload['screenWidth'], 1080);
    expect(env.payload['eventType'], 'tap');
  });

  test('permission labels exist for all permissions', () {
    for (final perm in Permissions.all) {
      expect(Permissions.label(perm), isNotEmpty);
    }
  });

  test('envelope round-trips through json', () {
    final env = Protocol.control(sessionId: 's1', kind: 'NAV_HOME');
    final decoded = WsEnvelope.fromJson(env.toJson());
    expect(decoded.type, 'CONTROL_EVENT');
    expect(decoded.payload['kind'], 'NAV_HOME');
  });
}
