import 'dart:async';

import 'package:call_ringer/call_ringer.dart';
import 'package:call_ringer/callkit_surface.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../data/models/voice_call.dart';
import '../decline-message/decline_replies.dart';
import '../ringtone/ring_holders.dart';
import 'android_call_lock_screen.dart';
import 'android_call_params.dart';
import 'call_ringing_ack.dart';
import 'incoming_call_admission.dart';

class AndroidCallUi {
  AndroidCallUi._();

  static final Set<String> _showingCallIds = <String>{};

  static Future<void> showIncomingFromCall(VoiceCall call) async {
    final replies = await DeclineReplies.nativeExtra();
    await _showOnce(AndroidCallParams.fromCall(call, replies: replies));
  }

  static Future<void> showIncomingFromPush(Map<String, dynamic> data) async {
    final replies = await DeclineReplies.nativeExtra();
    final params = AndroidCallParams.fromPush(data, replies: replies);
    if (params.id.isEmpty) return;
    await _showOnce(params);
  }

  static Future<void> startOutgoing(VoiceCall call, String currentUserId) =>
      FlutterCallkitIncoming.startCall(
        AndroidCallParams.forOutgoing(call, currentUserId),
      );

  /// Terminal push / WebSocket fallback: close the full-screen Activity,
  /// ringtone, notification actions and persisted native call together.
  static Future<void> endCall(String callId) async {
    if (callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {
      // The native call may already have been cleared by a local action.
    }
    // `endCall` broadcasts nothing when CallKit no longer holds a record for
    // this id — and its broadcast could not close the locked-screen Activity
    // anyway (see [CallkitSurface]). Ask for that dismissal outright.
    await CallkitSurface.dismissIncoming();
    await CallRinger.release(callRingHolderNative);
    // An Accept on a locked phone may be waiting for this call's screen; there
    // will be none, so the lock screen comes back now.
    await AndroidCallLockScreen.release(callId);
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
    // `hideCallkitIncoming` clears the notification only; the full-screen
    // Activity a locked phone raised needs its own dismissal, and this path
    // emits no CallKit event for the native bridge to act on.
    await CallkitSurface.dismissIncoming();
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
    if (!_showingCallIds.add(params.id)) return;
    try {
      // The reference app's busy rule: only an idle phone rings. A phone
      // placing, answering or talking on a call — this one included, when a
      // push for it arrives late or twice — shows no ringing screen and plays
      // no tone. This is the "still ringing after I answered" / "second caller
      // screen" report: the old gate let the late push through and nothing took
      // it down, because an `accepted` call is not over.
      if (await CallRinger.liveCall() != null) return;
      final active = await FlutterCallkitIncoming.activeCalls();
      final decision = decideIncomingCallAdmission(
        params.id,
        active.map(
          (call) =>
              NativeCallSnapshot(id: call.id, isAccepted: call.isAccepted),
        ),
      );
      switch (decision) {
        case IncomingCallAdmission.ignoreAccepted:
          // A redelivered incoming push must never re-arm the ringtone after
          // the same call has already been accepted.
          await CallRinger.release(callRingHolderNative);
          return;
        case IncomingCallAdmission.ignoreBusy:
          return;
        case IncomingCallAdmission.restoreRinging:
          // CallKit persists across process death; restore only its lost tone.
          await CallRinger.hold(
            callRingHolderNative,
            requireNotificationUi: true,
          );
          return;
        case IncomingCallAdmission.show:
          await CallRinger.hold(
            callRingHolderNative,
            requireNotificationUi: true,
          );
          await FlutterCallkitIncoming.showCallkitIncoming(params);
          // Group invites have no caller waiting on a "Ringing…" line.
          if (params.extra?['type'] != 'group_call') {
            unawaited(postVoiceCallRingingAck(params.id));
          }
          return;
      }
    } finally {
      _showingCallIds.remove(params.id);
    }
  }
}
