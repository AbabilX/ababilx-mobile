import 'package:ababilx/core/network/ws_client.dart';
import 'package:ababilx/features/calls/data/voice_call_repository.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:ababilx/features/calls/webrtc/voice_peer_engine.dart';
import 'package:ababilx/features/calls/webrtc/voice_peer_engine_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'call_fake_engine.dart';
import 'call_fakes.dart';

export 'call_fake_engine.dart';
export 'call_fakes.dart';

/// Channels the call path talks to and whose answers no test cares about.
const _quietChannels = [
  'flutter_callkit_incoming_events',
  'com.ababilx.app/call_lock_screen',
  'com.ababilx.app/call_ringer',
  'com.ababilx.app/call_screen_lock',
  'xyz.luan/audioplayers.global',
  'xyz.luan/audioplayers.global/events',
  'xyz.luan/audioplayers',
  'xyz.luan/audioplayers/events/ababilx_call_ringtone',
  'dev.fluttercommunity.plus/connectivity_status',
  'plugins.it_nomads.com/flutter_secure_storage',
];

/// The real [VoiceCallNotifier] over a fake server, socket, engine and
/// CallKit.
///
/// On the real clock, like the other notifier tests here, with the two
/// production delays shortened ([kTestResetDelay], [kTestRetryDelay]). The
/// binding's fake clock was tried and dropped: the ringtone keeps a static
/// future chain, and a future made under one test's fake zone never completes
/// for the next.
class CallHarness {
  final repo = FakeCalls();
  final ws = FakeWs();

  /// Every engine built, in order.
  final engines = <FakeEngine>[];

  /// Every call made to the CallKit plugin.
  final native = <MethodCall>[];

  /// What CallKit reports as its active calls.
  var nativeCalls = <Map<String, dynamic>>[];

  /// Every line logged.
  final logs = <String>[];

  late final ProviderContainer container;
  DebugPrintCallback? _print;

  TestCalls get calls =>
      container.read(voiceCallProvider.notifier) as TestCalls;

  VoiceCallState get state => container.read(voiceCallProvider);

  /// Call ids whose native surface was ended.
  List<String> get nativeEnded => [
    for (final call in native)
      if (call.method == 'endCall') '${(call.arguments as Map?)?['id']}',
  ];

  bool logged(String event, [String? containing]) => logs.any(
    (line) =>
        line.contains(event) &&
        (containing == null || line.contains(containing)),
  );

  Future<void> start({VoiceCallState? initial}) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in _quietChannels) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_callkit_incoming'),
      (call) async {
        native.add(call);
        return call.method == 'activeCalls' ? nativeCalls : null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    _print = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    container = ProviderContainer(
      overrides: [
        wsClientProvider.overrideWithValue(ws),
        voiceCallRepositoryProvider.overrideWithValue(repo),
        voicePeerEngineFactoryProvider.overrideWithValue(_buildEngine),
        voiceCallProvider.overrideWith(
          () => TestCalls(initial ?? const VoiceCallState(currentUserId: 'me')),
        ),
      ],
    );
    await calls.bootstrap();
    await settle();
  }

  /// Runs everything that needs no time to pass.
  Future<void> settle() => pumpEventQueue();

  Future<void> wait(Duration duration) async {
    await Future<void>.delayed(duration);
    await settle();
  }

  /// Long enough for a reset armed before this call to have fired.
  Future<void> pastReset() => wait(kTestResetDelay * 2);

  /// A socket event about [id].
  Future<void> event(
    String type,
    String id, {
    String status = 'ringing',
  }) async {
    ws.incoming.add({'type': type, 'call': callJson(id, status: status)});
    await settle();
  }

  /// [id] rings, is answered, and its media connects.
  Future<FakeEngine> connect(String id) async {
    await event('call.incoming', id);
    await calls.acceptIncoming(id);
    await settle();
    final engine = engines.last;
    engine.connected();
    await settle();
    return engine;
  }

  Future<void> close() async {
    await calls.shutdown();
    await settle();
    container.dispose();
    final original = _print;
    if (original != null) debugPrint = original;
  }

  VoicePeerEngine _buildEngine({
    required VoiceSignalSender sendSignal,
    required void Function() onConnected,
    required void Function(String reason) onFailed,
    required void Function(String reason, {bool immediate}) onTrouble,
    required void Function() onHealthy,
    required void Function(DateTime intervalStart) onMediaFlowing,
    required void Function() onRestartRequested,
    required void Function(bool sharing) onLocalScreenChanged,
    required void Function(MediaStream? stream) onRemoteScreenChanged,
    required void Function(MediaStream? stream, {required bool front})
    onLocalCameraChanged,
    required void Function(MediaStream? stream) onRemoteCameraChanged,
    required bool isOfferer,
  }) {
    final engine = FakeEngine(connected: onConnected);
    engines.add(engine);
    return engine;
  }
}

/// One test over a started [CallHarness], closed whatever the outcome.
void callTest(
  String description,
  Future<void> Function(CallHarness h) body, {
  VoiceCallState? initial,
}) {
  test(description, () async {
    final h = CallHarness();
    await h.start(initial: initial);
    try {
      await body(h);
    } finally {
      await h.close();
    }
  });
}
