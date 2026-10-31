import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_audio_output.dart';

/// Dart's side of the native call-audio owner (`CallAudioSession.kt`, the
/// port of the reference app's audio manager). Commands go down; every change
/// of device — a Bluetooth headset connecting, a wired one plugged in, the
/// user's pick — comes back up as a `devices` event. Android only: elsewhere
/// every call is a no-op and the list stays empty.
class CallAudioDeviceChannel {
  const CallAudioDeviceChannel._();

  static const MethodChannel _channel = MethodChannel(
    'com.ababilx.app/call_audio',
  );

  static final StreamController<CallAudioDevices> _changes =
      StreamController<CallAudioDevices>.broadcast();
  static bool _bound = false;
  static CallAudioDevices _current = CallAudioDevices.empty;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static CallAudioDevices get current => _current;

  static Stream<CallAudioDevices> get changes {
    _bind();
    return _changes.stream;
  }

  static void _bind() {
    if (_bound || !supported) return;
    _bound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'devices') return;
      final args = call.arguments;
      _current = args is Map
          ? CallAudioDevices.fromMap(args)
          : CallAudioDevices.empty;
      _changes.add(_current);
    });
  }

  /// Starts the call's audio, or joins it when the ringback already did.
  /// [user] is a choice made before media existed (a Speaker press while
  /// ringing); null leaves the pick to the device order.
  static Future<void> start({
    String? callId,
    required bool defaultSpeaker,
    CallAudioOutput? user,
  }) => _invoke('start', {
    'callId': callId,
    'defaultSpeaker': defaultSpeaker,
    if (user != null) 'userDevice': callAudioOutputToWire(user),
  });

  /// The reference app's `SetDefaultDevice`.
  static Future<void> setDefault({
    required bool speaker,
    bool clearEarpiece = false,
  }) => _invoke('setDefault', {
    'speaker': speaker,
    'clearEarpiece': clearEarpiece,
  });

  /// The reference app's `SetUserDevice` with a picker row's id.
  static Future<void> select(CallAudioOption option) =>
      _invoke('select', {'id': option.id});

  /// The first device of [output]'s kind, as a press on that row would.
  static Future<void> selectOutput(CallAudioOutput output) =>
      _invoke('selectType', {'type': callAudioOutputToWire(output)});

  static Future<void> stop() => _invoke('stop');

  static Future<void> _invoke(String method, [Object? args]) async {
    if (!supported) return;
    _bind();
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // A host without the channel has no device routing to offer.
    } on PlatformException {
      // Routing is best effort; the call goes on on whatever it has.
    }
  }
}

/// The call's audio devices, for the output button and the picker.
final callAudioDevicesProvider = StreamProvider<CallAudioDevices>((ref) async* {
  yield CallAudioDeviceChannel.current;
  yield* CallAudioDeviceChannel.changes;
});
