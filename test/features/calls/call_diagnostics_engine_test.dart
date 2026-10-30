import 'package:ababilx/features/calls/diagnostics/call_audio_health.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_state.dart';
import 'package:ababilx/features/calls/webrtc/voice_peer_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ending the call leaves no reading behind', () async {
    callDiagnostics.value = const CallDiagnosticsState(
      health: CallAudioHealthReport(status: CallAudioHealth.healthy),
    );
    final engine = VoicePeerEngine(
      sendSignal: (_) async => true,
      onConnected: () {},
      onFailed: (_) {},
      onTrouble: (_, {immediate = false}) {},
      onHealthy: () {},
      onRestartRequested: () {},
      onLocalScreenChanged: (_) {},
      onRemoteScreenChanged: (_) {},
      onLocalCameraChanged: (_, {required front}) {},
      onRemoteCameraChanged: (_) {},
      isOfferer: true,
    );
    await engine.dispose();
    expect(callDiagnostics.value, isNull);
  });
}
