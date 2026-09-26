import 'package:ababilx/core/network/ws_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/calls/audio/call_audio_route.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// "I pressed loudspeaker while it was ringing, and when they answered the
/// call went back to the earpiece." A press made before the media exists has
/// nothing to route, and opening the media forced the earpiece and then reset
/// the Speaker flag to `cameraOn`, dropping the choice.
VoiceCall _call() => VoiceCall(
  id: 'call',
  teamId: '',
  conversationId: 'chat',
  callerId: 'me',
  calleeId: 'peer',
  status: 'ringing',
  callerName: 'Me',
  calleeName: 'Peer',
  expiresAt: DateTime.now().add(const Duration(minutes: 1)),
  createdAt: DateTime.now(),
);

class _Calls extends VoiceCallNotifier {
  _Calls(this.initial);
  final VoiceCallState initial;
  @override
  VoiceCallState build() => initial;
}

class _OfflineWs extends WsClient {
  _OfflineWs() : super(const SecureStorage(FlutterSecureStorage()));
  @override
  Future<void> connect() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('where the media opens', () {
    test('a Speaker press made while ringing wins', () {
      expect(
        CallAudioRoute.startsOnSpeaker(chosen: true, camera: false),
        isTrue,
      );
    });

    test('choosing the earpiece on a video call wins too', () {
      expect(
        CallAudioRoute.startsOnSpeaker(chosen: false, camera: true),
        isFalse,
      );
    });

    test('untouched: earpiece for audio, loudspeaker with the camera', () {
      expect(
        CallAudioRoute.startsOnSpeaker(chosen: null, camera: false),
        isFalse,
      );
      expect(
        CallAudioRoute.startsOnSpeaker(chosen: null, camera: true),
        isTrue,
      );
    });
  });

  test('the choice lasts for the call and not into the next one', () {
    const fresh = VoiceCallState();
    expect(fresh.speakerChoice, isNull);
    final chosen = fresh.copyWith(speaker: true, speakerChosen: true);
    expect(chosen.speakerChoice, isTrue);
    expect(
      chosen.copyWith(phase: VoiceCallPhase.connecting).speakerChoice,
      isTrue,
    );
    expect(chosen.copyWith(speaker: false).speakerChoice, isFalse);
  });

  test('Speaker pressed while the other phone rings is remembered', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'flutter_callkit_incoming',
      'flutter_callkit_incoming_events',
      'com.ababilx.app/call_lock_screen',
      'com.ababilx.app/call_ringer',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    final c = ProviderContainer(
      overrides: [
        wsClientProvider.overrideWithValue(_OfflineWs()),
        voiceCallProvider.overrideWith(
          () => _Calls(
            VoiceCallState(
              currentUserId: 'me',
              phase: VoiceCallPhase.outgoingRinging,
              call: _call(),
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(voiceCallProvider.notifier).toggleSpeaker();

    final state = c.read(voiceCallProvider);
    expect(state.speaker, isTrue);
    expect(state.speakerChoice, isTrue);
  });
}
