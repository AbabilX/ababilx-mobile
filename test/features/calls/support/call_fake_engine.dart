import 'dart:async';

import 'package:ababilx/features/calls/data/models/ice_server.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:ababilx/features/calls/webrtc/voice_peer_engine.dart';

/// The production delays, shortened so a test waits on the real clock.
const kTestResetDelay = Duration(milliseconds: 300);
const kTestRetryDelay = Duration(milliseconds: 60);

/// Media for one call, without a microphone or a peer connection.
class FakeEngine implements VoicePeerEngine {
  FakeEngine({required this.connected});

  /// The owner's `onConnected`, so a test can report media flowing.
  final void Function() connected;

  /// Held open, `dispose` stays in flight — a teardown the test can pause.
  Completer<void>? disposeGate;

  bool prepared = false;
  bool disposed = false;

  /// First offers and repeats of them, as `createAndSendOffer` was asked.
  int offers = 0;
  int offerRetries = 0;
  bool answered = false;

  @override
  bool get ready => prepared && !disposed;

  @override
  bool get speakerOn => false;

  @override
  bool get cameraOn => false;

  @override
  bool get answerReceived => answered;

  @override
  Future<void> createAndSendOffer({bool renegotiate = false}) async {
    renegotiate ? offerRetries++ : offers++;
  }

  @override
  Future<void> prepare({
    required List<IceServer> iceServers,
    bool video = false,
    bool? speaker,
  }) async {
    prepared = true;
  }

  @override
  Future<void> dispose() async {
    await disposeGate?.future;
    disposed = true;
  }

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> handleSignal(Map<String, dynamic> signal) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The notifier under test, started from a state the test chooses. It can
/// also write state directly — the one thing no production path may do
/// without claiming it, which is how a stale timer is made to fire.
class TestCalls extends VoiceCallNotifier {
  TestCalls(this.initial);

  final VoiceCallState initial;

  @override
  VoiceCallState build() => initial;

  @override
  Duration get resetDelay => kTestResetDelay;

  @override
  Duration get socketBeforeAcceptBudget => kTestRetryDelay;

  @override
  List<Duration> get offerRetryDelays => const [
    kTestRetryDelay,
    kTestRetryDelay,
    kTestRetryDelay,
  ];

  @override
  List<Duration> get lookupRetryDelays => const [
    kTestRetryDelay,
    kTestRetryDelay,
    kTestRetryDelay,
  ];

  void force(VoiceCallState next) => state = next;
}
