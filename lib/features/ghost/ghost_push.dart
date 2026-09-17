import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/localization/app_translations.dart';
import '../notifications/local_notifications.dart';

/// Ghost Chat's two data-only pushes: `ghost_invite` wakes a phone whose app
/// is not on screen, `ghost_closed` takes that notification back down once
/// the invite was answered, declined, cancelled or answered on another device.
///
/// The notification is only a doorbell. Tapping it opens the app, the socket
/// connects, and the server replays the invite if it is still ringing — so an
/// invite that expired in the shade simply opens the chat list. The push
/// carries the inviter's name and nothing else, because nothing else exists.
bool isGhostPush(Map<String, dynamic> data) =>
    data['type'] == 'ghost_invite' || data['type'] == 'ghost_closed';

const ghostNotificationChannel = 'ghost_chat';

Future<void> handleGhostPush(
  LocalNotifications local,
  Map<String, dynamic> data, {
  required bool appOnScreen,
}) async {
  final sessionId = data['session_id']?.toString() ?? '';
  if (sessionId.isEmpty) return;
  final id = ghostNotificationId(sessionId);
  if (data['type'] == 'ghost_closed') {
    await local.cancel(id);
    return;
  }
  // On screen, the socket has already raised the invite screen.
  if (appOnScreen) return;
  final expires = DateTime.tryParse(data['expires_at']?.toString() ?? '');
  final left = expires?.difference(DateTime.now());
  if (left != null && left.isNegative) return;

  final name = data['inviter_name']?.toString().trim() ?? '';
  await local.showDetails(
    id: id,
    title: AppTranslations.of('en', 'ghost_chip'),
    body: AppTranslations.of(
      'en',
      'ghost_invite_title',
    ).replaceAll('{name}', name.isEmpty ? 'Someone' : name),
    payload: LocalNotifications.encodePayload('/messages', {
      'type': 'ghost_invite',
      'session_id': sessionId,
    }),
    android: AndroidNotificationDetails(
      ghostNotificationChannel,
      'Ghost Chat',
      channelDescription: 'Ghost Chat invites',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      icon: 'ic_stat_ababilx',
      autoCancel: true,
      // The invite rings for a minute; the entry must not outlive it.
      timeoutAfter: left?.inMilliseconds,
    ),
  );
}

/// A stable positive id per session, so `ghost_closed` finds its invite.
int ghostNotificationId(String sessionId) {
  var hash = 0x811c9dc5;
  for (final unit in sessionId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
