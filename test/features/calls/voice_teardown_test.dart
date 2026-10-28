import 'dart:async';

import 'package:ababilx/features/calls/webrtc/voice_teardown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const short = Duration(milliseconds: 50);

  test('runs every step in order', () async {
    final ran = <String>[];
    final failed = await runTeardown([
      (name: 'mic', run: () async => ran.add('mic')),
      (name: 'peer', run: () async => ran.add('peer')),
      (name: 'audio', run: () async => ran.add('audio')),
    ], stepTimeout: short);
    expect(ran, ['mic', 'peer', 'audio']);
    expect(failed, isEmpty);
  });

  test('a throwing step does not stop the steps after it', () async {
    final ran = <String>[];
    final failed = await runTeardown([
      (name: 'screen', run: () async => throw StateError('channel gone')),
      (name: 'mic', run: () async => ran.add('mic')),
      (name: 'peer', run: () async => ran.add('peer')),
    ], stepTimeout: short);
    expect(ran, ['mic', 'peer']);
    expect(failed, ['screen']);
  });

  test('a step that throws synchronously is contained too', () async {
    final ran = <String>[];
    final failed = await runTeardown([
      (name: 'camera', run: () => throw StateError('sync')),
      (name: 'peer', run: () async => ran.add('peer')),
    ], stepTimeout: short);
    expect(ran, ['peer']);
    expect(failed, ['camera']);
  });

  test('a hanging step times out and the rest still run', () async {
    final ran = <String>[];
    final hang = Completer<void>();
    final watch = Stopwatch()..start();
    final failed = await runTeardown([
      (name: 'screen', run: () => hang.future),
      (name: 'mic', run: () async => ran.add('mic')),
      (name: 'peer', run: () async => ran.add('peer')),
    ], stepTimeout: short);
    watch.stop();
    expect(ran, ['mic', 'peer']);
    expect(failed, ['screen']);
    // Bounded: one timeout, not forever.
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('every step hanging is still bounded by steps x timeout', () async {
    final watch = Stopwatch()..start();
    final failed = await runTeardown([
      for (var i = 0; i < 4; i++)
        (name: 'hang$i', run: () => Completer<void>().future),
    ], stepTimeout: short);
    watch.stop();
    expect(failed, ['hang0', 'hang1', 'hang2', 'hang3']);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('reports each failure with its name', () async {
    final reported = <String>[];
    await runTeardown(
      [
        (name: 'screen', run: () async => throw StateError('x')),
        (name: 'peer', run: () => Completer<void>().future),
      ],
      stepTimeout: short,
      onFailure: (name, error) => reported.add(name),
    );
    expect(reported, ['screen', 'peer']);
  });

  test('never throws, even when the reporter throws', () async {
    await expectLater(
      runTeardown(
        [(name: 'screen', run: () async => throw StateError('x'))],
        stepTimeout: short,
        onFailure: (_, _) => throw StateError('logger'),
      ),
      completes,
    );
  });

  test('the engine stops the microphone and closes the peer first', () {
    // The order the engine uses: capture and transmission end before any
    // step that can hang on a platform channel.
    expect(voiceEngineTeardownOrder.take(2), ['local_tracks', 'peer']);
    expect(
      voiceEngineTeardownOrder.indexOf('screen_share'),
      greaterThan(voiceEngineTeardownOrder.indexOf('peer')),
    );
    expect(
      voiceEngineTeardownOrder.indexOf('camera'),
      greaterThan(voiceEngineTeardownOrder.indexOf('peer')),
    );
    expect(voiceEngineTeardownOrder.last, 'audio_route');
  });
}
