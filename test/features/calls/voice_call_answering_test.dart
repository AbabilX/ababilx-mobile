import 'dart:async';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/network/ws_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/calls/call_ringtone.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/data/models/voice_call_session.dart';
import 'package:ababilx/features/calls/data/voice_call_api.dart';
import 'package:ababilx/features/calls/data/voice_call_repository.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// "I pressed Accept on the notification, the app opened and asked me to
/// accept again": between the press and the server's answer the provider sat
/// in `incomingRinging`, so the call screen drew the ringing view — Accept,
/// Decline and the ringtone — for the whole round trip.
VoiceCall _call(String status) => VoiceCall(
  id: 'call',
  teamId: '',
  conversationId: 'chat',
  callerId: 'caller',
  calleeId: 'me',
  status: status,
  callerName: 'Caller',
  calleeName: 'Me',
  expiresAt: DateTime.now().add(const Duration(minutes: 1)),
  createdAt: DateTime.now(),
);

VoiceCallSession _session(String status) =>
    VoiceCallSession(call: _call(status), iceServers: [], canControl: true);

class _SlowServer extends VoiceCallRepository {
  _SlowServer()
    : super(
        VoiceCallApi(ApiClient(const SecureStorage(FlutterSecureStorage()))),
      );

  final accepted = Completer<VoiceCallSession>();
  final actions = <String>[];

  @override
  Future<VoiceCallSession> get(String callId) async => _session('ringing');

  @override
  Future<VoiceCallSession> action(
    String id,
    String action, {
    String? reason,
  }) async {
    actions.add(action);
    if (action == 'accept') return accepted.future;
    return _session('ended');
  }
}

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
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var nativeCalls = <Map<String, dynamic>>[];
  late List<String> callkit;

  setUp(() {
    nativeCalls = [];
    callkit = [];
    for (final channel in [
      'com.ababilx.app/call_lock_screen',
      'com.ababilx.app/call_ringer',
      'flutter_callkit_incoming_events',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/events/ababilx_call_ringtone',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_callkit_incoming'),
      (method) async {
        callkit.add(method.method);
        return method.method == 'activeCalls' ? nativeCalls : null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => 1,
    );
  });

  ProviderContainer container(_SlowServer server, VoiceCallState initial) {
    final c = ProviderContainer(
      overrides: [
        wsClientProvider.overrideWithValue(_OfflineWs()),
        voiceCallRepositoryProvider.overrideWithValue(server),
        voiceCallProvider.overrideWith(() => _Calls(initial)),
      ],
    );
    addTearDown(() async {
      c.read(voiceCallProvider.notifier).reset();
      await CallRingtone.releaseAll();
      c.dispose();
    });
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  final ringing = VoiceCallState(
    currentUserId: 'me',
    phase: VoiceCallPhase.incomingRinging,
    call: _call('ringing'),
  );

  test('Accept leaves the ringing screen at once, not when the server answers',
      () async {
    final server = _SlowServer();
    final c = container(server, ringing);
    unawaited(c.read(voiceCallProvider.notifier).acceptIncoming('call'));
    await settle();
    expect(server.actions, ['accept']);
    expect(c.read(voiceCallProvider).phase, VoiceCallPhase.connecting);
    expect(c.read(voiceCallProvider).active, isTrue);
  });

  test('coming back to the app while answering never rings again', () async {
    final server = _SlowServer();
    final c = container(server, ringing);
    final notifier = c.read(voiceCallProvider.notifier);
    nativeCalls = [
      {'id': 'call', 'isAccepted': true},
    ];
    unawaited(notifier.acceptIncoming('call'));
    await settle();
    // CallStoreSync's resume path, in order.
    await notifier.syncFromNativeIncoming();
    await notifier.ensureNativeIncomingUi();
    expect(CallRingtone.holds('dm'), isFalse);
    expect(callkit, isNot(contains('showCallkitIncoming')));
    expect(c.read(voiceCallProvider).phase, VoiceCallPhase.connecting);
  });

  test('a CallKit Accept adopted on a cold start goes straight to connecting',
      () async {
    final server = _SlowServer();
    final c = container(server, VoiceCallState(currentUserId: 'me'));
    nativeCalls = [
      {'id': 'call', 'isAccepted': true},
    ];
    unawaited(c.read(voiceCallProvider.notifier).syncFromNativeIncoming());
    await settle();
    expect(server.actions, ['accept']);
    expect(c.read(voiceCallProvider).phase, VoiceCallPhase.connecting);
  });

  test('hanging up before the server answered declines, then ends the late '
      'accept', () async {
    final server = _SlowServer();
    final c = container(server, ringing);
    final notifier = c.read(voiceCallProvider.notifier);
    final accepting = notifier.acceptIncoming('call');
    await settle();
    await notifier.hangUp();
    expect(c.read(voiceCallProvider).active, isFalse);
    server.accepted.complete(_session('accepted'));
    await accepting;
    await settle();
    expect(server.actions, ['accept', 'decline', 'end']);
    expect(c.read(voiceCallProvider).active, isFalse);
  });

  test('an accept the network drops ends the call instead of hanging on '
      'connecting', () async {
    final server = _SlowServer();
    final c = container(server, ringing);
    final accepting = c
        .read(voiceCallProvider.notifier)
        .acceptIncoming('call');
    await settle();
    server.accepted.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/accept'),
        type: DioExceptionType.connectionError,
      ),
    );
    await accepting;
    await settle();
    expect(c.read(voiceCallProvider).active, isFalse);
  });
}
