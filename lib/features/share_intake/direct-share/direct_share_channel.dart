import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart end of `DirectShareChannel.kt`. Android only: iOS has no share
/// extension, and widget tests have no platform channels.
class DirectShareChannel {
  const DirectShareChannel();

  static const _method = MethodChannel('com.ababilx.app/direct_share');

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Replaces the share sheet's targets with [targets], best first.
  Future<void> publish(List<Map<String, Object>> targets) async {
    if (!_supported) return;
    try {
      await _method.invokeMethod<void>('publish', {'targets': targets});
    } on PlatformException catch (e) {
      debugPrint('[direct-share] publish failed: $e');
    }
  }

  Future<void> clear() async {
    if (!_supported) return;
    try {
      await _method.invokeMethod<void>('clear');
    } on PlatformException catch (e) {
      debugPrint('[direct-share] clear failed: $e');
    }
  }
}
