// LiveKit marks its audio-session API @experimental. It is still the only
// public way to drive the session it exclusively owns on Android, so the
// warning is accepted here rather than silently leaving calls on the earpiece.
// ignore_for_file: experimental_member_use

import 'dart:io' show Platform;

import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:livekit_client/livekit_client.dart'
    show
        AndroidAudioSessionConfiguration,
        AudioManager,
        AudioSessionManagementMode,
        AudioSessionOptions,
        AndroidAudioMode,
        AndroidAudioFocusMode,
        AndroidAudioStreamType,
        AndroidAudioAttributesUsageType,
        AndroidAudioAttributesContentType;

import '../voice_call_log.dart';

/// Speaker / earpiece routing for a 1:1 DM call.
///
/// **Do not route these calls through `Helper.setSpeakerphoneOn`.** LiveKit's
/// Android plugin calls `AudioSwitchManager.setAudioSessionManagementEnabled(
/// false)` when it attaches to the engine, which is at app start and is
/// process-wide. From that moment every flutter_webrtc audio call — speaker,
/// output selection, session start — returns without doing anything, which is
/// why the Speaker button did nothing and every call stayed on the earpiece.
///
/// LiveKit owns the Android audio session for the whole app, so a raw WebRTC
/// call has to drive it through the same owner. Group calls need nothing here:
/// a LiveKit `Room` configures the session on connect by itself.
class CallAudioRoute {
  const CallAudioRoute._();

  /// LiveKit's communication preset — the same mode, focus, stream and
  /// attributes the call used to ask flutter_webrtc for — plus forced routing,
  /// which some Android devices need or they keep a DM call on a stale route.
  static const _dmCallSession = AudioSessionOptions.communication(
    android: AndroidAudioSessionConfiguration(
      audioMode: AndroidAudioMode.inCommunication,
      manageAudioFocus: true,
      focusMode: AndroidAudioFocusMode.gain,
      streamType: AndroidAudioStreamType.voiceCall,
      usageType: AndroidAudioAttributesUsageType.voiceCommunication,
      contentType: AndroidAudioAttributesContentType.speech,
      forceAudioRouting: true,
    ),
  );

  /// Puts Android into a communication session for a DM call and applies the
  /// starting route. Also the point where audio focus and `MODE_IN_COMMUNICATION`
  /// are acquired, so it belongs at connect, never while the phone is ringing.
  static Future<void> activate({required bool speaker}) async {
    if (Platform.isIOS) {
      await Helper.setSpeakerphoneOn(speaker);
      return;
    }
    if (!Platform.isAndroid) return;
    try {
      // Preference first: applying the session configuration reads it.
      await AudioManager.instance.setSpeakerOutputPreferred(speaker);
      await AudioManager.instance.setAudioSessionOptions(_dmCallSession);
    } catch (error) {
      voiceCallLog('audio.activate.fail', reason: error.toString());
    }
  }

  /// Speaker button. [on] forces the speaker even with a headset connected —
  /// pressing it is an explicit choice of where the call should come out.
  static Future<void> setSpeaker(bool on) async {
    if (Platform.isIOS) {
      await Helper.setSpeakerphoneOn(on);
      return;
    }
    if (!Platform.isAndroid) return;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(on, force: on);
    } catch (error) {
      voiceCallLog('audio.speaker.fail', reason: error.toString());
    }
  }

  /// Ends the call's audio session: releases focus and restores the phone's
  /// normal audio mode.
  ///
  /// LiveKit is left in manual mode, because handing management back here would
  /// immediately re-activate the session it was just asked to drop.
  /// [restoreForRoom] is the other half of that contract, called before a group
  /// call connects.
  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    try {
      await AudioManager.instance.deactivateAudioSession();
    } catch (error) {
      voiceCallLog('audio.release.fail', reason: error.toString());
    }
  }

  /// Hands the audio session back to LiveKit so a `Room` manages it again.
  /// Safe to call when it already owns it.
  static Future<void> restoreForRoom() async {
    if (!Platform.isAndroid) return;
    try {
      await AudioManager.instance.setAudioSessionManagementMode(
        AudioSessionManagementMode.automatic,
      );
    } catch (error) {
      voiceCallLog('audio.restore.fail', reason: error.toString());
    }
  }
}
