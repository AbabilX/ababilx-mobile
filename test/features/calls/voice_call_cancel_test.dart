import 'dart:async';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/calls/data/voice_call_api.dart';
import 'package:ababilx/features/calls/data/voice_call_repository.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/data/models/voice_call_session.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceCall call(String status) => VoiceCall(
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
VoiceCallSession session(String status, {bool canControl = true}) =>
    VoiceCallSession(
      call: call(status),
      iceServers: [],
      canControl: canControl,
    );

class DelayedCalls extends VoiceCallRepository {
  DelayedCalls()
    : super(
        VoiceCallApi(ApiClient(const SecureStorage(FlutterSecureStorage()))),
      );
  final started = Completer<VoiceCallSession>();
  final accepted = Completer<VoiceCallSession>();
  final actions = <String>[];
  @override
  Future<VoiceCallSession> start(String conversationId, {bool video = false}) =>
      started.future;
  @override
  Future<VoiceCallSession> action(
    String id,
    String action, {
    String? reason,
  }) async {
    actions.add(action);
    if (action == 'accept') return accepted.future;
    return session('ended');
  }
}

class TestCalls extends VoiceCallNotifier {
  TestCalls(this.initial);
  final VoiceCallState initial;
  @override
  VoiceCallState build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    for (final channel in [
      'flutter_callkit_incoming',
      'com.ababilx.app/call_lock_screen',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/events/ababilx_call_ringtone',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (_) async => 1,
        );
  });
  test('End cancels starting call and ends a late successful start', () async {
    final repo = DelayedCalls();
    final container = ProviderContainer(
      overrides: [
        voiceCallRepositoryProvider.overrideWithValue(repo),
        voiceCallProvider.overrideWith(
          () => TestCalls(const VoiceCallState(currentUserId: 'caller')),
        ),
      ],
    );
    final notifier = container.read(voiceCallProvider.notifier);
    final starting = notifier.startOutgoing(
      ChatConversation.fromJson({
        'id': 'chat',
        'type': 'dm',
        'peer_user_id': 'me',
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(voiceCallProvider).phase, VoiceCallPhase.starting);
    final ending = notifier.hangUp();
    await Future<void>.delayed(Duration.zero);
    await ending;
    expect(container.read(voiceCallProvider).phase, VoiceCallPhase.ended);
    repo.started.complete(session('ringing'));
    await Future<void>.delayed(Duration.zero);
    await starting;
    expect(repo.actions, contains('end'));
    expect(container.read(voiceCallProvider).active, isFalse);
    container.read(voiceCallProvider.notifier).reset();
    container.dispose();
  });
  test('End during accept cannot be undone by the accept response', () async {
    final repo = DelayedCalls();
    final container = ProviderContainer(
      overrides: [
        voiceCallRepositoryProvider.overrideWithValue(repo),
        voiceCallProvider.overrideWith(
          () => TestCalls(
            VoiceCallState(
              currentUserId: 'me',
              phase: VoiceCallPhase.incomingRinging,
              call: call('ringing'),
            ),
          ),
        ),
      ],
    );
    final notifier = container.read(voiceCallProvider.notifier);
    final accepting = notifier.acceptIncoming();
    await Future<void>.delayed(Duration.zero);
    expect(repo.actions, contains('accept'));
    final ending = notifier.hangUp();
    await Future<void>.delayed(Duration.zero);
    await ending;
    repo.accepted.complete(session('accepted'));
    await Future<void>.delayed(Duration.zero);
    await accepting;
    expect(container.read(voiceCallProvider).active, isFalse);
    expect(repo.actions, contains('end'));
    container.read(voiceCallProvider.notifier).reset();
    container.dispose();
  });
  test('an accept owned by another session never starts media', () async {
    final repo = DelayedCalls();
    final container = ProviderContainer(
      overrides: [
        voiceCallRepositoryProvider.overrideWithValue(repo),
        voiceCallProvider.overrideWith(
          () => TestCalls(
            VoiceCallState(
              currentUserId: 'me',
              phase: VoiceCallPhase.incomingRinging,
              call: call('ringing'),
            ),
          ),
        ),
      ],
    );
    final accepting = container
        .read(voiceCallProvider.notifier)
        .acceptIncoming();
    await Future<void>.delayed(Duration.zero);
    repo.accepted.complete(session('accepted', canControl: false));
    await Future<void>.delayed(Duration.zero);
    await accepting;
    expect(container.read(voiceCallProvider).active, isFalse);
    expect(repo.actions, ['accept']);
    container.read(voiceCallProvider.notifier).reset();
    container.dispose();
  });
}
