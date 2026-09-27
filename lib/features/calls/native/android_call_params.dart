import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';

import '../data/models/voice_call.dart';

class AndroidCallParams {
  const AndroidCallParams._();

  /// Suppresses the plugin's own "on a call" notification and the foreground
  /// service behind it.
  ///
  /// It defaults to on, and it is not the notification this app wants: the
  /// shade ended up with two ongoing-call entries for one call, each with its
  /// own Hang up button, and the one the user reached for was as likely to be
  /// the plugin's as ours. `OngoingCallService` posts the single entry now —
  /// Signal's `CallStyle` shape, a chronometer, and a Hang up wired straight
  /// into `VoiceCallNotifier`.
  static const _noOngoingNotification = NotificationParams(
    showNotification: false,
  );

  static const _background = '#0B0B0F';
  static const _text = '#FFFFFF';
  static const _answer = '#3AB55B';

  /// [replies] is [DeclineReplies.nativeExtra]: the Message button on the
  /// full-screen ringing Activity and its preset texts.
  static CallKitParams fromCall(
    VoiceCall call, {
    Map<String, String> replies = const {},
  }) => _incoming(
    callId: call.id,
    conversationId: call.conversationId,
    callerId: call.callerId,
    callerName: call.callerName,
    callerAvatarUrl: call.callerAvatarUrl,
    expiresAt: call.expiresAt,
    video: call.isVideo,
    replies: replies,
  );

  static CallKitParams fromPush(
    Map<String, dynamic> data, {
    Map<String, String> replies = const {},
  }) {
    final expiresAt =
        DateTime.tryParse(data['expires_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now().add(const Duration(seconds: 60));
    return _incoming(
      callId: data['call_id']?.toString() ?? '',
      conversationId: data['conversation_id']?.toString() ?? '',
      callerId: data['caller_id']?.toString() ?? '',
      callerName: data['caller_name']?.toString() ?? 'AbabilX call',
      callerAvatarUrl: data['caller_avatar_url']?.toString(),
      expiresAt: expiresAt,
      video: data['mode']?.toString() == 'video',
      replies: replies,
    );
  }

  static CallKitParams forOutgoing(VoiceCall call, String currentUserId) =>
      CallKitParams(
        id: call.id,
        nameCaller: call.peerName(currentUserId),
        appName: 'AbabilX',
        avatar: call.peerAvatar(currentUserId),
        handle: call.isVideo ? 'Video call' : 'Voice call',
        type: call.isVideo ? 1 : 0,
        callingNotification: _noOngoingNotification,
        extra: {
          'type': 'voice_call',
          'call_id': call.id,
          'conversation_id': call.conversationId,
          'mode': call.mode,
        },
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          isShowCallID: false,
          backgroundColor: _background,
          textColor: _text,
          actionColor: _answer,
          ringtonePath: 'silent_ring',
          incomingCallNotificationChannelName: 'Voice calls',
          missedCallNotificationChannelName: 'Missed voice calls',
          isImportant: true,
        ),
      );

  static CallKitParams _incoming({
    required String callId,
    required String conversationId,
    required String callerId,
    required String callerName,
    required String? callerAvatarUrl,
    required DateTime expiresAt,
    bool video = false,
    Map<String, String> replies = const {},
  }) {
    final remaining = expiresAt.difference(DateTime.now()).inMilliseconds;
    return CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'AbabilX',
      avatar: callerAvatarUrl,
      handle: video ? 'Video call' : 'Voice call',
      // 1 = video on both CallKit and the plugin's Android surface, which
      // swaps the icon and the accept label.
      type: video ? 1 : 0,
      duration: remaining.clamp(1000, 60000),
      callingNotification: _noOngoingNotification,
      missedCallNotification: NotificationParams(
        showNotification: true,
        subtitle: video ? 'Missed video call' : 'Missed voice call',
        callbackText: 'Call back',
        isShowCallback: true,
      ),
      extra: {
        'type': 'voice_call',
        'call_id': callId,
        'conversation_id': conversationId,
        'caller_id': callerId,
        'caller_name': callerName,
        'caller_avatar_url': callerAvatarUrl ?? '',
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'mode': video ? 'video' : 'audio',
        ...replies,
      },
      android: AndroidParams(
        isCustomNotification: true,
        backgroundUrl: (callerAvatarUrl?.trim().isEmpty ?? true)
            ? null
            : callerAvatarUrl,
        backgroundColor: _background,
        textColor: _text,
        actionColor: _answer,
        isShowLogo: false,
        isShowCallID: false,
        ringtonePath: 'silent_ring',
        incomingCallNotificationChannelName: 'Voice calls',
        missedCallNotificationChannelName: 'Missed voice calls',
        isShowFullLockedScreen: true,
        isImportant: true,
        isFullScreen: false,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
    );
  }
}
