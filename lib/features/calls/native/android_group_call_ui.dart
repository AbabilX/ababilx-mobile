import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:call_ringer/call_ringer.dart';
import 'package:call_ringer/callkit_surface.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../group/data/models/group_call.dart';
import '../ringtone/ring_holders.dart';
import 'android_call_lock_screen.dart';

part 'android_group_call_params.dart';

/// Native CallKit surface for channel group calls — the same treatment the 1:1
/// DM path gets from [AndroidCallUi]: a full-screen ringing UI that works from
/// a killed app, and, once joined, an ongoing-call notification backed by the
/// `phoneCall|microphone` foreground service so Android keeps the SFU audio
/// alive when the app is not on screen.
///
/// Kept separate from [AndroidCallUi] because the two call systems share no
/// lifecycle: a group call has no callee, no decline that reaches the server,
/// and it keeps running after this device stops ringing.
class AndroidGroupCallUi {
  AndroidGroupCallUi._();

  /// Ring window, matching `groupCallRingWindow` and the server's push TTL.
  static const ringWindow = Duration(seconds: 60);

  static const callType = 'group_call';

  /// CallKit events carry the params back, so [callType] is how the DM and the
  /// group listener tell each other's calls apart.
  static bool isGroupCall(CallKitParams? params) =>
      params?.extra?['type'] == callType;

  static String conversationIdOf(CallKitParams? params) =>
      params?.extra?['conversation_id']?.toString() ?? '';

  /// Rebuilds enough of the call to hand a native ring back to the in-app
  /// invite when the user opens the app without answering. Returns null when
  /// the params are not a group-call ring.
  static GroupCall? callFrom(CallKitParams? params) {
    final extra = params?.extra;
    if (!isGroupCall(params) || extra == null) return null;
    final id = extra['call_id']?.toString() ?? params!.id;
    final conversationId = extra['conversation_id']?.toString() ?? '';
    if (id.isEmpty || conversationId.isEmpty) return null;
    return GroupCall(
      id: id,
      teamId: extra['team_id']?.toString() ?? '',
      conversationId: conversationId,
      startedBy: extra['started_by']?.toString() ?? '',
      starterName: extra['starter_name']?.toString() ?? 'Someone',
      starterAvatarUrl: extra['starter_avatar_url']?.toString(),
      conversationName: extra['conversation_name']?.toString(),
      status: 'live',
      maxParticipants: 0,
      participantCount: 0,
      startedAt:
          DateTime.tryParse(extra['started_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  static CallKitParams paramsFromCall(GroupCall call) => _params(
    callId: call.id,
    conversationId: call.conversationId,
    teamId: call.teamId,
    startedBy: call.startedBy,
    starterName: call.starterName,
    starterAvatarUrl: call.starterAvatarUrl,
    channelName: call.title,
    startedAt: call.startedAt,
  );

  static CallKitParams paramsFromPush(Map<String, dynamic> data) {
    final startedAt =
        DateTime.tryParse(data['started_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    final channel = data['conversation_name']?.toString().trim();
    return _params(
      callId: data['call_id']?.toString() ?? '',
      conversationId: data['conversation_id']?.toString() ?? '',
      teamId: data['team_id']?.toString() ?? '',
      startedBy: data['started_by']?.toString() ?? '',
      starterName: data['starter_name']?.toString() ?? 'Someone',
      starterAvatarUrl: data['starter_avatar_url']?.toString(),
      channelName: (channel == null || channel.isEmpty)
          ? 'Group call'
          : channel,
      startedAt: startedAt,
    );
  }

  static Future<void> showIncomingFromCall(GroupCall call) =>
      _showOnce(paramsFromCall(call));

  static Future<void> showIncomingFromPush(Map<String, dynamic> data) async {
    final params = paramsFromPush(data);
    if (params.id.isEmpty) return;
    await _showOnce(params);
  }

  /// Clears the native ringing UI without ending the call — the call keeps
  /// running for everyone else, and this device may still join from the header.
  static Future<void> hideIncoming(String callId) async {
    if (callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(
        CallKitParams(id: callId),
      );
    } catch (_) {
      // Nothing native was showing.
    }
    // A locked screen raised the plugin's full-screen Activity, which its own
    // teardown cannot close — see [CallkitSurface].
    await CallkitSurface.dismissIncoming();
    // Hiding emits no call event: release CallKit's hold on the native ringer
    // explicitly, or it would keep ringing into the joined call.
    await CallRinger.release(callRingHolderNative);
  }

  /// Promotes the call to "connected", which is what starts the foreground
  /// service and its ongoing notification.
  static Future<void> startOngoing(GroupCall call) async {
    try {
      await FlutterCallkitIncoming.startCall(_ongoingParams(call));
      await FlutterCallkitIncoming.setCallConnected(call.id);
    } catch (_) {
      // The call itself must not fail because the notification did.
    }
  }

  static Future<void> endOngoing(String callId) async {
    await endCall(callId);
  }

  /// Stops either a ringing or ongoing native group-call surface and removes
  /// it from CallKit's persisted active-call registry. `hideIncoming` only
  /// hides the pixels/sound and intentionally keeps the record for a Flutter
  /// hand-off; terminal/decline paths must use this method instead.
  static Future<void> endCall(String callId) async {
    if (callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
    await CallkitSurface.dismissIncoming();
    await CallRinger.release(callRingHolderNative);
    // An Accept on a locked phone may be waiting for this call's screen; there
    // will be none, so the lock screen comes back now.
    await AndroidCallLockScreen.release(callId);
  }

  /// Shows the native ringing UI and starts the tone that belongs to it —
  /// CallKit's own player is silent by design (see `_params`), so the sound
  /// comes from `call_ringer` and is held until the call is joined, ignored,
  /// ended, or handed over to the Flutter UI.
  static Future<void> _showOnce(CallKitParams params) async {
    // Hold first, then dedupe the UI — see [AndroidCallUi].
    await CallRinger.hold(callRingHolderNative, requireNotificationUi: true);
    final active = await FlutterCallkitIncoming.activeCalls();
    if (active.any((call) => call.id == params.id)) return;
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}
