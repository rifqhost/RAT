import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

/// Coordinate normalization: map controller-local pixels into 0..1 and then
/// to agent resolution. This test locks the formula used by the remote overlay
/// so both apps stay consistent.
void main() {
  double normalizeX(double localX, double localWidth) =>
      (localX / localWidth).clamp(0.0, 1.0);
  double normalizeY(double localY, double localHeight) =>
      (localY / localHeight).clamp(0.0, 1.0);
  double denormalizeX(double nx, int agentWidth) => nx * agentWidth;
  double denormalizeY(double ny, int agentHeight) => ny * agentHeight;

  test('center maps to 0.5 on both devices regardless of resolution', () {
    // Controller 1080x2400
    final nx = normalizeX(540, 1080);
    final ny = normalizeY(1200, 2400);
    expect(nx, closeTo(0.5, 0.001));
    expect(ny, closeTo(0.5, 0.001));
    // Agent 1440x3200
    expect(denormalizeX(nx, 1440), closeTo(720, 0.001));
    expect(denormalizeY(ny, 3200), closeTo(1600, 0.001));
  });

  test('top-left maps to 0,0', () {
    final nx = normalizeX(0, 1080);
    final ny = normalizeY(0, 2400);
    expect(nx, 0.0);
    expect(ny, 0.0);
  });

  test('out-of-bounds is clamped to 0..1', () {
    expect(normalizeX(-50, 1080), 0.0);
    expect(normalizeY(99999, 2400), 1.0);
  });

  test('round trip preserves position', () {
    final rng = Random(42);
    for (var i = 0; i < 100; i++) {
      final lx = rng.nextDouble() * 1080;
      final ly = rng.nextDouble() * 2400;
      final nx = normalizeX(lx, 1080);
      final ny = normalizeY(ly, 2400);
      final ax = denormalizeX(nx, 1440);
      final ay = denormalizeY(ny, 3200);
      // fractional rounding is applied on the agent side
      expect(ax / 1440, closeTo(nx, 0.002));
      expect(ay / 3200, closeTo(ny, 0.002));
    }
  });
}
