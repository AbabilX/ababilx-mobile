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
  /// [hidden] are locked chats: a copy pinned to the home screen is blanked.
  Future<void> publish(
    List<Map<String, Object>> targets,
    List<String> hidden,
  ) async {
    if (!_supported) return;
    try {
      await _method.invokeMethod<void>('publish', {
        'targets': targets,
        'hidden': hidden,
      });
    } on PlatformException catch (e) {
      debugPrint('[direct-share] publish failed: $e');
    }
  }

  /// Chats that just had a message, oldest first: Android ranks the share
  /// sheet by this usage and shows little without it.
  Future<void> reportUsed(List<String> ids) async {
    if (!_supported || ids.isEmpty) return;
    try {
      await _method.invokeMethod<void>('reportUsed', {'ids': ids});
    } on PlatformException catch (e) {
      debugPrint('[direct-share] report failed: $e');
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
