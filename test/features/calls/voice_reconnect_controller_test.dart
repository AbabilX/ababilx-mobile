import 'dart:async';

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

  group('media seen moving', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['wifi'],
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (_) async => null,
      );
    });

    VoiceReconnectController build(List<bool> changes) =>
        VoiceReconnectController(
          isOfferer: () => true,
          restart: () async {},
          requestPeerRestart: () async {},
          onGaveUp: (_) {},
          onReconnectingChanged: changes.add,
        );

    testWidgets('packets from before the trouble began do not end it', (
      tester,
    ) async {
      final changes = <bool>[];
      final controller = build(changes);
      await tester.pump();
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      controller.noteTrouble('network_changed', immediate: true);
      controller.noteMediaFlowing(before);
      expect(controller.reconnecting, isTrue);
      expect(changes, [true]);
      await tester.runAsync(controller.dispose);
    });

    testWidgets('a whole interval after it does', (tester) async {
      final changes = <bool>[];
      final controller = build(changes);
      await tester.pump();
      controller.noteTrouble('network_changed', immediate: true);
      controller.noteMediaFlowing(
        DateTime.now().add(const Duration(milliseconds: 1)),
      );
      expect(controller.reconnecting, isFalse);
      expect(changes, [true, false]);
      await tester.runAsync(controller.dispose);
    });

    testWidgets('a healthy call is left alone', (tester) async {
      final changes = <bool>[];
      final controller = build(changes);
      await tester.pump();
      controller.noteMediaFlowing(DateTime.now());
      expect(changes, isEmpty);
      await tester.runAsync(controller.dispose);
    });
  });

  group('the socket coming back', () {
    late MethodChannel methods;
    late MethodChannel events;

    setUp(() {
      methods = const MethodChannel('dev.fluttercommunity.plus/connectivity');
      events = const MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(methods, (_) async => ['wifi']);
      messenger.setMockMethodCallHandler(events, (_) async => null);
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockMethodCallHandler(events, null);
    });

    testWidgets('restarts at once instead of sitting out the backoff', (
      tester,
    ) async {
      var attempts = 0;
      final controller = VoiceReconnectController(
        isOfferer: () => true,
        restart: () async => attempts++,
        requestPeerRestart: () async {},
        onGaveUp: (_) {},
        onReconnectingChanged: (_) {},
        policy: const VoiceReconnectPolicy(backoff: [Duration(seconds: 30)]),
      );
      await tester.pump();
      controller.noteTrouble('lost', immediate: true);
      await tester.pump(const Duration(milliseconds: 1));
      expect(attempts, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 1);

      controller.noteSignallingBack();
      await tester.pump(const Duration(milliseconds: 1));
      expect(attempts, 2);
      await tester.runAsync(controller.dispose);
    });

    testWidgets('a healthy call is left alone', (tester) async {
      var attempts = 0;
      final controller = VoiceReconnectController(
        isOfferer: () => true,
        restart: () async => attempts++,
        requestPeerRestart: () async {},
        onGaveUp: (_) {},
        onReconnectingChanged: (_) {},
      );
      await tester.pump();
      controller.noteSignallingBack();
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 0);
      await tester.runAsync(controller.dispose);
    });

    testWidgets('an attempt already opening the socket is not doubled', (
      tester,
    ) async {
      var attempts = 0;
      final gate = Completer<void>();
      final controller = VoiceReconnectController(
        isOfferer: () => true,
        restart: () async {
          attempts++;
          await gate.future;
        },
        requestPeerRestart: () async {},
        onGaveUp: (_) {},
        onReconnectingChanged: (_) {},
        policy: const VoiceReconnectPolicy(backoff: [Duration(seconds: 30)]),
      );
      await tester.pump();
      controller.noteTrouble('lost', immediate: true);
      await tester.pump(const Duration(milliseconds: 1));
      expect(attempts, 1);

      // This attempt's own `connect` is what brought the socket back.
      controller.noteSignallingBack();
      gate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(attempts, 1);
      await tester.runAsync(controller.dispose);
    });
  });
}
