import 'package:call_ringer/call_ringer.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../data/models/voice_call.dart';
import '../ringtone/ring_holders.dart';

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
      isShowLogo: false,
      isShowCallID: false,
      // Outgoing calls never ring on this device; the silent file keeps the
      // plugin's sound player out of the way. See the incoming params below.
      ringtonePath: 'silent_ring',
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
        // Keep the native caller surface as simple as the in-app receiver:
        // caller identity plus the two call actions, without a second logo.
        isShowLogo: false,
        isShowCallID: false,
        // Deliberately silent: `CallkitSoundPlayerManager` stops its ringtone
        // on ACTION_SCREEN_OFF and on any VOLUME_CHANGED_ACTION broadcast, so
        // an OEM ring-volume ramp or a screen blink killed the tone seconds
        // into a call. The `call_ringer` plugin plays the real tone for every
        // path instead, held for as long as this surface is up. Vibration and
        // the notification still come from this plugin.
        ringtonePath: 'silent_ring',
        incomingCallNotificationChannelName: 'Voice calls',
        missedCallNotificationChannelName: 'Missed voice calls',
        isShowFullLockedScreen: true,
        isImportant: true,
        // Keep this false: the plugin's direct-Activity branch shows the
        // caller screen but skips its ringtone player. The high-priority call
        // notification still launches the same full-screen UI (including over
        // the lock screen) and starts the configured system ringtone first.
        isFullScreen: false,
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

  /// Terminal push / WebSocket fallback: close the full-screen Activity,
  /// ringtone, notification actions and persisted native call together.
  static Future<void> endCall(String callId) async {
    if (callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {
      // The native call may already have been cleared by a local action.
    }
    await CallRinger.release(callRingHolderNative);
  }

  /// Clears the native incoming UI + its ringtone without ending the call and
  /// without emitting a CallKit event, so the Flutter `/call` screen can take
  /// over as the single visible ringing UI. Used when the app is in the
  /// foreground — two ringing UIs fight over audio focus and one goes silent.
  static Future<void> hideIncoming(String callId) async {
    if (callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(
        CallKitParams(id: callId),
      );
    } catch (_) {
      // Nothing native was showing — the Flutter screen is already alone.
    }
    // Hiding emits no call event, so the native ringer has to be told that
    // CallKit no longer wants the tone; the Flutter screen keeps its own hold.
    await CallRinger.release(callRingHolderNative);
  }

  /// Whether CallKit currently has a native call record for [callId] — the
  /// real signal for "is there a native ringer to hand off from", instead of
  /// assuming one on every lifecycle tick.
  static Future<bool> isShowing(String callId) async {
    if (callId.isEmpty) return false;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      return active.any((call) => call.id == callId);
    } catch (_) {
      return false;
    }
  }

  /// Shows the native incoming UI and starts the ringtone that goes with it.
  /// CallKit's own player is silent by design (see [_params]), so the tone
  /// comes from `call_ringer`, held until the call is answered, declined,
  /// ended, or handed to the Flutter call screen.
  static Future<void> _showOnce(CallKitParams params) async {
    // Hold first, then dedupe the UI: CallKit keeps its call record across a
    // process death, so a restarted process can find the screen already up
    // with nothing ringing behind it.
    await CallRinger.hold(callRingHolderNative, requireNotificationUi: true);
    final active = await FlutterCallkitIncoming.activeCalls();
    if (active.any((call) => call.id == params.id)) return;
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}
