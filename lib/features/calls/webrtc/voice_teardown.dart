import 'dart:async';

import '../voice_call_log.dart';

/// One named piece of ending a call.
typedef TeardownStep = ({String name, Future<void> Function() run});

/// The order [VoicePeerEngine.dispose] ends a call in. Capture and
/// transmission stop first — the microphone track, then the peer connection —
/// so no later step that waits on a platform channel (screen share, camera,
/// audio route) can leave a call sending audio after the screen says ended.
const voiceEngineTeardownOrder = <String>[
  'local_tracks',
  'peer',
  // Apart from `peer`: a close that hangs must not also skip the release.
  'peer_dispose',
  'screen_share',
  'camera',
  'local_stream',
  'remote_state',
  'communication_device',
  'audio_route',
];

/// Upper bound for one step. A platform channel that never answers must not
/// hold the rest of the teardown hostage.
const voiceTeardownStepTimeout = Duration(seconds: 3);

/// Runs [steps] in order, each on its own: a step that throws or outlasts
/// [stepTimeout] is reported and the next one still runs. Never throws.
///
/// RingRTC shipped the opposite (CVE-2026-113380): each teardown step returned
/// early on error, so one failure before `close()` left a call's audio flowing
/// after the app had said it was over. Returns the names of the failed steps.
Future<List<String>> runTeardown(
  List<TeardownStep> steps, {
  Duration stepTimeout = voiceTeardownStepTimeout,
  void Function(String name, Object error)? onFailure,
}) async {
  final failed = <String>[];
  for (final step in steps) {
    try {
      await Future.sync(step.run).timeout(stepTimeout);
    } catch (error) {
      failed.add(step.name);
      try {
        (onFailure ?? _logFailure)(step.name, error);
      } catch (_) {
        // A broken reporter must not stop the teardown either.
      }
    }
  }
  return failed;
}

void _logFailure(String name, Object error) {
  voiceCallLog('engine.teardown.failed', source: name, reason: '$error');
}
