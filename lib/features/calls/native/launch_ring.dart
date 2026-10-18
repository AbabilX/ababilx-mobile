import 'dart:io' show Platform;

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../data/models/voice_call.dart';
import 'android_group_call_ui.dart';
import 'native_ring_call.dart';
import 'voice_call_ended_guard.dart';

/// A DM ring that was already on the phone when this engine started.
class LaunchRingRecord {
  const LaunchRingRecord({required this.call, required this.accepted});

  final VoiceCall call;

  /// Answer was pressed on the notification before the app was running.
  final bool accepted;
}

/// The ring that started the app, read once before `runApp`.
///
/// A killed app is opened by the ring itself — the notification's
/// full-screen intent, a tap on it, or its Answer button. Before this, the
/// first screen drawn was the chat list, and the call screen came only after
/// the socket handshake and a server lookup: two to three seconds of a phone
/// that was ringing with nothing to answer on. Read here, the call provider
/// starts in the ringing (or answering) state and the router opens `/call`
/// as the very first screen; the server is asked right after.
abstract final class LaunchRing {
  static LaunchRingRecord? _pending;

  /// Android only — iOS has no CallKit records of this shape. Never throws:
  /// a launch must not fail on a call lookup.
  static Future<void> read() async {
    if (!Platform.isAndroid) return;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      for (final native in active) {
        if (AndroidGroupCallUi.isGroupCall(native)) continue;
        final call = voiceCallFromNativeRing(native.extra, id: native.id);
        if (call == null) continue;
        if (await VoiceCallEndedGuard.wasEnded(native.id)) continue;
        _pending = LaunchRingRecord(call: call, accepted: native.isAccepted);
        return;
      }
    } catch (_) {
      // No ring to start on; the ordinary recovery still runs.
    }
  }

  /// Handed out once, to the call provider's first build.
  static LaunchRingRecord? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }
}
