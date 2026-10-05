import 'package:flutter/services.dart';

/// Android's Wi-Fi locks.
///
/// Without a `MulticastLock` most phones filter multicast out before the app
/// sees it, so discovery only ever worked in one direction. Held only while
/// discovery runs — it costs battery, which is why Android makes apps ask.
abstract final class LocalShareNet {
  static const _channel = MethodChannel('com.ababilx.app/local_share_net');

  static Future<void> acquire() => _call('acquire');
  static Future<void> release() => _call('release');

  /// A transfer is running: keep the process and the Wi-Fi radio awake.
  static Future<void> transferStarted() => _call('transferStarted');
  static Future<void> transferEnded() => _call('transferEnded');

  static Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // No such channel on this platform or build.
    }
  }
}
