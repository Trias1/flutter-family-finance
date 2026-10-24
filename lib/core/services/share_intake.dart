import 'dart:async';

import 'package:flutter/services.dart';

/// Images shared into the app (Share -> Family Finance). Android copies the
/// image into the app's cache and keeps its path until Flutter takes it, so
/// a share that launched the app waits through sign-in and the app lock.
class ShareIntake {
  static const _channel = MethodChannel('family_finance/share');
  static final _shared = StreamController<void>.broadcast();
  static bool _listening = false;

  /// Fires when an image is shared while the app is already running.
  static Stream<void> get onShared {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'sharedImage') _shared.add(null);
      });
    }
    return _shared.stream;
  }

  /// The waiting image's path, once; null when nothing was shared.
  static Future<String?> take() async {
    try {
      return await _channel.invokeMethod<String>('takeSharedImage');
    } catch (_) {
      return null;
    }
  }
}
