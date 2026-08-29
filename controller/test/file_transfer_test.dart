import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// File integrity / checksum helpers used by the transfer service.
void main() {
  String sha256Hex(String data) => sha256.convert(utf8.encode(data)).toString();

  test('sha256 of a string is stable and 64 hex chars', () {
    final a = sha256Hex('hello');
    final b = sha256Hex('hello');
    expect(a, b);
    expect(a.length, 64);
  });

  test('different content produces different checksum', () {
    expect(sha256Hex('a'), isNot(equals(sha256Hex('b'))));
  });

  test('fraction clamps between 0 and 1', () {
    double fraction(int transferred, int total) => total == 0 ? 0 : (transferred / total).clamp(0.0, 1.0);
    expect(fraction(50, 100), 0.5);
    expect(fraction(150, 100), 1.0);
    expect(fraction(0, 100), 0.0);
    expect(fraction(0, 0), 0.0);
  });
}
