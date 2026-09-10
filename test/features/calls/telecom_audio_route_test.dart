import 'package:ababilx/features/calls/audio/telecom_audio_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.ababilx.app/call_audio_telecom');

/// Plain `test`, not `testWidgets`: nothing here draws, and the fake-async
/// zone of a widget test never delivers a platform reply.
Future<void> _on(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  late Object? Function(MethodCall call) answer;

  setUp(() {
    calls.clear();
    answer = (_) => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return answer(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('asks Telecom to route the call it hosts', () async {
    await _on(TargetPlatform.android, () async {
      expect(await TelecomAudioRoute.route('call-1', speaker: true), isTrue);
    });
    expect(calls.single.method, 'route');
    expect(calls.single.arguments, {'callId': 'call-1', 'speaker': true});
  });

  test('a call Telecom is not hosting stays with LiveKit', () async {
    answer = (_) => false;
    await _on(TargetPlatform.android, () async {
      expect(await TelecomAudioRoute.route('call-1', speaker: false), isFalse);
    });
    expect(calls.single.arguments, {'callId': 'call-1', 'speaker': false});
  });

  test('no call id never reaches the host', () async {
    await _on(TargetPlatform.android, () async {
      expect(await TelecomAudioRoute.route(null, speaker: true), isFalse);
      expect(await TelecomAudioRoute.route('', speaker: true), isFalse);
    });
    expect(calls, isEmpty);
  });

  test('a host without the channel falls back', () async {
    answer = (_) => throw MissingPluginException();
    await _on(TargetPlatform.android, () async {
      expect(await TelecomAudioRoute.route('call-1', speaker: true), isFalse);
    });
  });

  test('a native error falls back', () async {
    answer = (_) => throw PlatformException(code: 'telecom');
    await _on(TargetPlatform.android, () async {
      expect(await TelecomAudioRoute.route('call-1', speaker: true), isFalse);
    });
  });

  test('off Android nothing is asked', () async {
    await _on(TargetPlatform.iOS, () async {
      expect(await TelecomAudioRoute.route('call-1', speaker: true), isFalse);
    });
    expect(calls, isEmpty);
  });
}
