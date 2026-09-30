import 'dart:io' show Platform;

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'android_call_params.dart';

/// "Missed voice call" in the shade for a 1:1 call nobody answered.
///
/// WhatsApp's behaviour, and until now ours only when CallKit's own ring timed
/// out on this phone. A call the caller hung up on, or one whose ring never
/// reached this phone at all — asleep, offline, the push lost — left no trace
/// outside the chat.
///
/// The server marks the callee's ended push `missed_call=1` and names the
/// caller in it; that copy keeps FCM high priority precisely because it is
/// shown (every other ended push is silent and goes normal). The entry is
/// CallKit's own missed-call notification, so it carries the id the ring's
/// timeout gives it — `"missing_<call id>".hashCode()` in Kotlin. If that one
/// is already up, this does nothing rather than play the sound a second time.
class MissedCallNotice {
  MissedCallNotice._();

  static bool applies(Map<String, dynamic> data) =>
      data['type']?.toString() == 'voice_call_ended' &&
      data['missed_call']?.toString() == '1' &&
      (data['call_id']?.toString().isNotEmpty ?? false);

  /// Best effort and never throws: it runs in the FCM background isolate.
  static Future<void> showIfMissed(Map<String, dynamic> data) async {
    if (!Platform.isAndroid || !applies(data)) return;
    try {
      if (await _alreadyShown(data['call_id'].toString())) return;
      await FlutterCallkitIncoming.showMissCallNotification(
        AndroidCallParams.fromPush(data),
      );
    } catch (_) {
      // A missing notice is a lesser failure than a crashed isolate.
    }
  }

  static Future<bool> _alreadyShown(String callId) async {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final active = await android?.getActiveNotifications() ?? const [];
    final id = missedCallNotificationId(callId);
    return active.any((entry) => entry.id == id);
  }
}

/// The id CallKit posts its missed-call entry under for [callId].
int missedCallNotificationId(String callId) =>
    javaStringHashCode('missing_$callId');

/// `java.lang.String.hashCode()`: s[0]·31^(n−1) + … + s[n−1] over UTF-16 code
/// units, wrapped to a signed 32-bit int.
int javaStringHashCode(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (31 * hash + unit) & 0xFFFFFFFF;
  }
  return hash >= 0x80000000 ? hash - 0x100000000 : hash;
}
