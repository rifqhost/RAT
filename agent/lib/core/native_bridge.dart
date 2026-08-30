import 'package:flutter/services.dart';

/// MethodChannel bridge to the native AccessibilityService.
///
/// The native side (MainActivity + RMODZAccessibilityService) receives
/// touch/control/text commands here and forwards them to the running
/// accessibility service, which performs global actions and gesture dispatch.
class NativeBridge {
  static const MethodChannel _channel = MethodChannel('rmodz_native');

  NativeBridge._();

  /// Whether the RMODZ accessibility service is currently enabled.
  static Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system accessibility settings so the user can enable the service.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } on PlatformException {
      // ignore
    }
  }

  /// Broadcasts a touch event (down/move/up) at normalized (0..1) coordinates.
  ///
  /// [action] is one of ACTION_DOWN=0, ACTION_UP=1, ACTION_MOVE=2.
  static Future<void> dispatchTouch({
    required int action,
    required double x,
    required double y,
    int? pointerId,
  }) async {
    try {
      await _channel.invokeMethod<void>('dispatchTouch', {
        'action': action,
        'x': x,
        'y': y,
        'pointerId': ?pointerId,
      });
    } on PlatformException {
      // ignore
    }
  }

  /// Dispatches a system global action: BACK, HOME, RECENTS.
  static Future<void> globalAction(String action) async {
    try {
      await _channel.invokeMethod<void>('globalAction', {'action': action});
    } on PlatformException {
      // ignore
    }
  }

  /// Injects text into the currently focused field.
  static Future<void> setText(String text) async {
    try {
      await _channel.invokeMethod<void>('setText', {'text': text});
    } on PlatformException {
      // ignore
    }
  }
}
