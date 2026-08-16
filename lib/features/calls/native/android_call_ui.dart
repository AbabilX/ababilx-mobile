import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../data/models/voice_call.dart';

class AndroidCallUi {
  AndroidCallUi._();

  static CallKitParams paramsFromCall(VoiceCall call) => _params(
    callId: call.id,
    conversationId: call.conversationId,
    callerId: call.callerId,
    callerName: call.callerName,
    callerAvatarUrl: call.callerAvatarUrl,
    expiresAt: call.expiresAt,
  );

  static CallKitParams paramsForOutgoing(
    VoiceCall call,
    String currentUserId,
  ) => CallKitParams(
    id: call.id,
    nameCaller: call.peerName(currentUserId),
    appName: 'AbabilX',
    avatar: call.peerAvatar(currentUserId),
    handle: 'Voice call',
    type: 0,
    callingNotification: const NotificationParams(
      showNotification: true,
      subtitle: 'Voice call',
    ),
    extra: {
      'type': 'voice_call',
      'call_id': call.id,
      'conversation_id': call.conversationId,
    },
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: true,
      logoUrl: 'assets/icon/icon.png',
      isShowCallID: false,
      // Bundled app ringtone (android/app/src/main/res/raw/clear_agenda.mp3),
      // the same tone the in-app dialog and the web client play.
      ringtonePath: 'clear_agenda',
      incomingCallNotificationChannelName: 'Voice calls',
      missedCallNotificationChannelName: 'Missed voice calls',
      isImportant: true,
    ),
  );

  static CallKitParams paramsFromPush(Map<String, dynamic> data) {
    final expiresAt =
        DateTime.tryParse(data['expires_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now().add(const Duration(seconds: 60));
    return _params(
      callId: data['call_id']?.toString() ?? '',
      conversationId: data['conversation_id']?.toString() ?? '',
      callerId: data['caller_id']?.toString() ?? '',
      callerName: data['caller_name']?.toString() ?? 'AbabilX call',
      callerAvatarUrl: data['caller_avatar_url']?.toString(),
      expiresAt: expiresAt,
    );
  }

  static CallKitParams _params({
    required String callId,
    required String conversationId,
    required String callerId,
    required String callerName,
    required String? callerAvatarUrl,
    required DateTime expiresAt,
  }) {
    final remaining = expiresAt.difference(DateTime.now()).inMilliseconds;
    return CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'AbabilX',
      avatar: callerAvatarUrl,
      handle: 'Voice call',
      type: 0,
      duration: remaining.clamp(1000, 60000),
      missedCallNotification: const NotificationParams(
        showNotification: true,
        subtitle: 'Missed voice call',
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
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        logoUrl: 'assets/icon/icon.png',
        isShowCallID: false,
        ringtonePath: 'clear_agenda',
        incomingCallNotificationChannelName: 'Voice calls',
        missedCallNotificationChannelName: 'Missed voice calls',
        isShowFullLockedScreen: true,
        isImportant: true,
        isFullScreen: true,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
    );
  }

  static Future<void> showIncomingFromCall(VoiceCall call) async {
    await _showOnce(paramsFromCall(call));
  }

  static Future<void> showIncomingFromPush(Map<String, dynamic> data) async {
    final params = paramsFromPush(data);
    if (params.id.isEmpty) return;
    await _showOnce(params);
  }

  static Future<void> startOutgoing(VoiceCall call, String currentUserId) =>
      FlutterCallkitIncoming.startCall(paramsForOutgoing(call, currentUserId));

  static Future<void> _showOnce(CallKitParams params) async {
    final active = await FlutterCallkitIncoming.activeCalls();
    if (active.any((call) => call.id == params.id)) return;
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}
