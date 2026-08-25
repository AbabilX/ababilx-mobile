import 'package:call_ringer/call_ringer.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';

import 'ring_holders.dart';

/// Stop the CallKit-side ringtone when a CallKit event says the ringing UI is
/// finished — answered, declined, ended, or rung out.
///
/// The native ringer is deliberately deaf to screen state, audio focus and
/// volume changes (that is what kept silencing the tone), so call lifecycle is
/// the only thing that stops it. Every isolate that listens to CallKit events
/// funnels through here: the UI isolate's two call providers and the
/// background handler that serves a killed app. Called before either provider
/// filters events by call system, because both share one ringer.
///
/// The in-app `/call` screen holds the ringtone separately, so this never
/// silences a call the Flutter UI is still presenting.
Future<void> releaseNativeRingOnCallKitEvent(CallEvent? event) async {
  switch (event) {
    case CallEventActionCallAccept():
    case CallEventActionCallDecline():
    case CallEventActionCallEnded():
    case CallEventActionCallTimeout():
      await CallRinger.release(callRingHolderNative);
    default:
      return;
  }
}
