// LiveKit marks its audio-session API @experimental. It is still the only
// public way to keep the session it owns by default out of a call's way.
// ignore_for_file: experimental_member_use

import 'dart:io' show Platform;

import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:livekit_client/livekit_client.dart'
    show AudioManager, AudioSessionManagementMode;

import '../voice_call_log.dart';
import 'call_audio_devices.dart';
import 'call_audio_output.dart';

/// Where a call's audio goes: earpiece, speaker, Bluetooth or wired headset.
///
/// **Android: one native owner, Signal's way.** `CallAudioSession.kt` ports
/// Signal-Android's `SignalAudioManager`: it holds mode, focus and the
/// communication device for the whole call, watches the device list, and
/// moves the call to a Bluetooth or wired headset the moment one connects —
/// unless the user picked something else. Under Android Telecom (a CallKit
/// Answer) it reports Telecom's routes and asks Telecom, as Signal's
/// `TelecomAudioManager` does. LiveKit's own AudioSwitch is kept out of it:
/// two owners of one audio mode is how the speaker choice used to be lost.
/// Never `Helper.setSpeakerphoneOn` on Android — LiveKit disables
/// flutter_webrtc's audio manager process-wide, so it is a silent no-op.
///
/// iOS keeps the speaker on/off switch it had.
class CallAudioRoute {
  const CallAudioRoute._();

  /// The DM call these routes belong to, so a Telecom-hosted one is found.
  static String? _callId;

  static void bindCall(String callId) => _callId = callId;

  /// Where a DM call's audio goes once its media opens: the user's Speaker
  /// press if there was one, else the loudspeaker with the camera on, else
  /// the earpiece. A connected headset outranks both defaults on Android.
  static bool startsOnSpeaker({required bool? chosen, required bool camera}) =>
      chosen ?? camera;

  /// Starts a DM call's audio session — Signal's Initialize + SetDefaultDevice
  /// (speaker for video, earpiece for audio) + a choice made while ringing.
  /// Also the point focus and `MODE_IN_COMMUNICATION` are taken, so it belongs
  /// to call setup, never to an incoming ring.
  static Future<void> activate({bool? chosen, bool video = false}) async {
    if (Platform.isIOS) {
      await Helper.setSpeakerphoneOn(
        startsOnSpeaker(chosen: chosen, camera: video),
      );
      return;
    }
    if (!Platform.isAndroid) return;
    await _keepLiveKitOut();
    await CallAudioDeviceChannel.start(
      callId: _callId,
      defaultSpeaker: video,
      user: chosen == null
          ? null
          : chosen
          ? CallAudioOutput.speaker
          : CallAudioOutput.handset,
    );
  }

  /// A group call's audio on Android: same owner, loudspeaker by default.
  /// iOS leaves the session to the `Room` and sets [preferRoomSpeaker].
  static Future<void> activateRoom({String? callId}) async {
    if (!Platform.isAndroid) return;
    await _keepLiveKitOut();
    await CallAudioDeviceChannel.start(callId: callId, defaultSpeaker: true);
  }

  /// The camera came on: Signal's `enableSpeakerPhoneIfNeeded` — a call on
  /// the earpiece moves to the speaker (the phone is held out to see), a
  /// headset stays.
  static Future<void> cameraStarted() async {
    if (!Platform.isAndroid) return;
    final active = CallAudioDeviceChannel.current.active;
    if (active != CallAudioOutput.handset && active != CallAudioOutput.none) {
      return;
    }
    await CallAudioDeviceChannel.setDefault(speaker: true, clearEarpiece: true);
  }

  /// Speaker on / off, for the two-way button (iOS, or before the device
  /// list arrives). Off on Android is the earpiece — or the headset in it.
  static Future<void> setSpeaker(bool on) async {
    if (Platform.isIOS) {
      await Helper.setSpeakerphoneOn(on);
      return;
    }
    if (!Platform.isAndroid) return;
    voiceCallLog('audio.speaker', callId: _callId, reason: '$on');
    await CallAudioDeviceChannel.selectOutput(
      on ? CallAudioOutput.speaker : CallAudioOutput.handset,
    );
  }

  /// A group call's starting speaker on iOS, where the `Room` owns the
  /// session. A no-op on Android: there the default is the native owner's,
  /// and forcing it here would take the call off a connected headset.
  static Future<void> preferRoomSpeaker(bool on) async {
    if (!Platform.isIOS) return;
    await AudioManager.instance.setSpeakerOutputPreferred(on);
  }

  /// A group call's two-way speaker button (iOS, or Android before the
  /// device list arrives).
  static Future<void> toggleRoomSpeaker(bool on) =>
      Platform.isAndroid ? setSpeaker(on) : preferRoomSpeaker(on);

  /// A row of the output picker, or the next one of a cycling press.
  static Future<void> select(CallAudioOption option) {
    voiceCallLog('audio.select', callId: _callId, reason: option.output.name);
    return CallAudioDeviceChannel.select(option);
  }

  /// Ends the call's audio session: focus released, the phone's own audio
  /// mode, speaker and microphone state put back.
  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    await CallAudioDeviceChannel.stop();
  }

  /// LiveKit starts in automatic mode and would configure its own session on
  /// a Room connect. Manual mode plus a stop leaves the call to our owner.
  static Future<void> _keepLiveKitOut() async {
    try {
      await AudioManager.instance.setAudioSessionManagementMode(
        AudioSessionManagementMode.manual,
      );
      await AudioManager.instance.deactivateAudioSession();
    } catch (error) {
      voiceCallLog('audio.livekit.fail', reason: error.toString());
    }
  }
}
