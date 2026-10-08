import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/data/models/voice_call_session.dart';
import 'package:ababilx/features/calls/data/voice_call_api.dart';
import 'package:ababilx/features/calls/data/voice_call_repository.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceCallSession _active(String status, String callerId) => VoiceCallSession(
  call: VoiceCall(
    id: 'other',
    teamId: '',
    conversationId: 'chat',
    callerId: callerId,
    calleeId: callerId == 'me' ? 'peer' : 'me',
    status: status,
    callerName: 'A',
    calleeName: 'B',
    expiresAt: DateTime.now().add(const Duration(minutes: 1)),
    createdAt: DateTime.now(),
  ),
  iceServers: [],
  canControl: true,
);

/// The account is busy server-side with [live]; every start is refused.
class _BusyCalls extends VoiceCallRepository {
  _BusyCalls(this.live)
    : super(
        VoiceCallApi(ApiClient(const SecureStorage(FlutterSecureStorage()))),
      );
  final VoiceCallSession live;
  final actions = <String>[];
  var starts = 0;

  @override
  Future<VoiceCallSession> start(String conversationId, {bool video = false}) {
    starts++;
    final request = RequestOptions(path: '/calls');
    throw DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 409,
        data: {'success': false, 'error': 'voice_call_busy_self'},
      ),
    );
  }

  @override
  Future<VoiceCallSession?> activeCall() async => live;

  @override
  Future<VoiceCallSession> action(
    String id,
    String action, {
    String? reason,
  }) async {
    actions.add('$action:$reason');
    return live;
  }
}

class _Calls extends VoiceCallNotifier {
  @override
  VoiceCallState build() => const VoiceCallState(currentUserId: 'me');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_callkit_incoming'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => 1,
    );
  });

  Future<_BusyCalls> startAgainst(VoiceCallSession live) async {
    final repo = _BusyCalls(live);
    final container = ProviderContainer(
      overrides: [
        voiceCallRepositoryProvider.overrideWithValue(repo),
        voiceCallProvider.overrideWith(_Calls.new),
      ],
    );
    final notifier = container.read(voiceCallProvider.notifier);
    await notifier.startOutgoing(
      ChatConversation.fromJson({
        'id': 'chat',
        'type': 'dm',
        'peer_user_id': 'peer',
      }),
    );
    expect(container.read(voiceCallProvider).phase, VoiceCallPhase.failed);
    notifier.reset();
    container.dispose();
    return repo;
  }

  test('a call still ringing this phone is never cleared as stale', () async {
    final repo = await startAgainst(_active('ringing', 'peer'));
    expect(repo.actions, isEmpty);
    expect(repo.starts, 1);
  });

  test('a dead accepted call is cleared and the start retried', () async {
    final repo = await startAgainst(_active('accepted', 'peer'));
    expect(repo.actions, ['fail:stale_call_recovered']);
    expect(repo.starts, 2);
  });

  test('our own unanswered call is cleared and the start retried', () async {
    final repo = await startAgainst(_active('ringing', 'me'));
    expect(repo.actions, ['fail:stale_call_recovered']);
    expect(repo.starts, 2);
  });
}
