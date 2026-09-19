import 'package:ababilx/features/calls/webrtc/voice_reconnect_controller.dart';
import 'package:ababilx/features/calls/webrtc/voice_reconnect_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recovery cancels the old deadline before a second outage', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const methods = MethodChannel('dev.fluttercommunity.plus/connectivity');
    const events = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    messenger.setMockMethodCallHandler(methods, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    final changes = <bool>[];
    final failures = <String>[];
    final controller = VoiceReconnectController(
      isOfferer: () => true,
      restart: () async {},
      requestPeerRestart: () async {},
      onGaveUp: failures.add,
      onReconnectingChanged: changes.add,
      policy: const VoiceReconnectPolicy(giveUpAfter: Duration(seconds: 10)),
    );
    await tester.pump();
    controller.noteTrouble('first_network_switch');
    await tester.pump(const Duration(seconds: 8));
    controller.noteHealthy();
    expect(controller.reconnecting, isFalse);
    controller.noteTrouble('second_network_switch');
    await tester.pump(const Duration(seconds: 3));
    expect(failures, isEmpty); // Past the first outage's deadline.
    controller.noteHealthy();
    await tester.pump(const Duration(seconds: 20));
    expect(failures, isEmpty);
    expect(changes, [true, false, true, false]);
    await tester.runAsync(controller.dispose);
  });
}
