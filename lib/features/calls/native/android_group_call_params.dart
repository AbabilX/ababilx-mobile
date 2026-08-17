part of 'android_group_call_ui.dart';

// CallKit payload builders for channel group calls. Split out so the UI class
// stays about *when* to ring and this file stays about *what* CallKit is handed
// — the ringing params and the ongoing (foreground-service) params.

CallKitParams _ongoingParams(GroupCall call) => CallKitParams(
  id: call.id,
  nameCaller: call.title,
  appName: 'AbabilX',
  avatar: call.starterAvatarUrl,
  handle: 'Group call',
  type: 0,
  callingNotification: const NotificationParams(
    showNotification: true,
    subtitle: 'Group call',
  ),
  extra: {
    'type': AndroidGroupCallUi.callType,
    'call_id': call.id,
    'conversation_id': call.conversationId,
  },
  android: const AndroidParams(
    isCustomNotification: true,
    isShowLogo: false,
    isShowCallID: false,
    incomingCallNotificationChannelName: 'Group calls',
    missedCallNotificationChannelName: 'Missed group calls',
    isImportant: true,
  ),
);

CallKitParams _params({
  required String callId,
  required String conversationId,
  required String teamId,
  required String startedBy,
  required String starterName,
  required String? starterAvatarUrl,
  required String channelName,
  required DateTime startedAt,
}) {
  final remaining = startedAt
      .add(AndroidGroupCallUi.ringWindow)
      .difference(DateTime.now())
      .inMilliseconds;
  return CallKitParams(
    id: callId,
    // The channel is what the user recognises; who started it is the subtitle.
    nameCaller: channelName,
    appName: 'AbabilX',
    avatar: starterAvatarUrl,
    handle: '$starterName started a group call',
    type: 0,
    duration: remaining.clamp(
      1000,
      AndroidGroupCallUi.ringWindow.inMilliseconds,
    ),
    missedCallNotification: const NotificationParams(
      showNotification: true,
      subtitle: 'Missed group call',
    ),
    extra: {
      'type': AndroidGroupCallUi.callType,
      'call_id': callId,
      'conversation_id': conversationId,
      'team_id': teamId,
      'started_by': startedBy,
      'starter_name': starterName,
      'starter_avatar_url': starterAvatarUrl ?? '',
      'conversation_name': channelName,
      'started_at': startedAt.toUtc().toIso8601String(),
    },
    android: const AndroidParams(
      isCustomNotification: true,
      // Match the deliberately minimal 1:1 native caller surface.
      isShowLogo: false,
      isShowCallID: false,
      // Same bundled tone as the DM ring and the web client.
      ringtonePath: 'clear_agenda',
      incomingCallNotificationChannelName: 'Group calls',
      missedCallNotificationChannelName: 'Missed group calls',
      isShowFullLockedScreen: true,
      isImportant: true,
      // The plugin's direct-Activity path does not start its sound player.
      // The notification full-screen intent gives the same caller screen and
      // keeps native ringing reliable when Flutter has been killed.
      isFullScreen: false,
      textAccept: 'Join',
      textDecline: 'Ignore',
    ),
  );
}
