import 'dart:io';

import 'package:ababilx/features/calls/webrtc/voice_audio_cap.dart';
import 'package:ababilx/features/calls/webrtc/voice_media_proof.dart';
import 'package:flutter_test/flutter_test.dart';

import 'call_diagnostics_scenarios.dart';

/// Every scripted call through the recovery proof and the voice cap: nothing
/// may throw on any report, and no scripted call has congestion to act on.
/// `LOAD=1 flutter test test/load/call_recovery_cap_load_test.dart`.
void main() {
  test(
    '12k calls: no throw, no cap without congestion',
    () {
      var capped = 0;
      var flowing = 0;
      for (var c = 0; c < 12000; c++) {
        final sim = Sim.values[c % Sim.values.length];
        final call = SimCall(sim, c);
        final proof = VoiceMediaProof();
        final cap = VoiceAudioCap();
        for (var i = 0; i < 150; i++) {
          final stats = call.report(tickFor(sim, i));
          if (proof.update(stats)) flowing++;
          final action = cap.update(
            remoteLossPercent: audioRemoteLossPercent(stats),
            rttMs: 50,
            pathKey: 'p',
            videoSending: false,
            live: true,
            nowMs: i * 2000,
          );
          if (action != VoiceCapAction.none) capped++;
        }
      }
      // ignore: avoid_print
      print('capped=$capped flowing=$flowing');
      expect(capped, 0);
      expect(flowing, greaterThan(0));
    },
    skip: Platform.environment['LOAD'] == '1' ? false : 'set LOAD=1',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
