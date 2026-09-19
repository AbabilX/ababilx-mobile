import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:ababilx/features/calls/native/native_call_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = 'flutter_callkit_incoming_events';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final platformCalls = <String>[];

  setUp(() {
    platformCalls.clear();
    messenger.setMockMethodCallHandler(const MethodChannel(channel), (
      call,
    ) async {
      platformCalls.add(call.method);
      return null;
    });
  });

  Future<void> emit(String action) async {
    await messenger.handlePlatformMessage(
      channel,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'event': 'com.hiennv.flutter_callkit_incoming.$action',
        'body': {'id': 'call-1'},
      }),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'DM and group listeners both receive native decline and accept',
    () async {
      final dm = <CallEvent?>[];
      final group = <CallEvent?>[];
      final first = NativeCallEvents.stream.listen(dm.add);
      final second = NativeCallEvents.stream.listen(group.add);
      addTearDown(() async {
        await first.cancel();
        await second.cancel();
      });
      await Future<void>.delayed(Duration.zero);
      await emit('ACTION_CALL_DECLINE');
      await emit('ACTION_CALL_ACCEPT');
      expect(dm, [
        isA<CallEventActionCallDecline>(),
        isA<CallEventActionCallAccept>(),
      ]);
      expect(group, [
        isA<CallEventActionCallDecline>(),
        isA<CallEventActionCallAccept>(),
      ]);
      expect(platformCalls, ['listen']);
    },
  );

  test('removing either listener leaves the other connected', () async {
    final dm = <CallEvent?>[];
    final group = <CallEvent?>[];
    final first = NativeCallEvents.stream.listen(dm.add);
    final second = NativeCallEvents.stream.listen(group.add);
    await Future<void>.delayed(Duration.zero);
    await first.cancel();
    addTearDown(second.cancel);
    await emit('ACTION_CALL_DECLINE');
    expect(group, [isA<CallEventActionCallDecline>()]);
    expect(platformCalls, ['listen']);
    await second.cancel();
    expect(platformCalls, ['listen', 'cancel']);

    final restarted = NativeCallEvents.stream.listen(dm.add);
    addTearDown(restarted.cancel);
    await Future<void>.delayed(Duration.zero);
    await emit('ACTION_CALL_ENDED');
    expect(dm, [isA<CallEventActionCallEnded>()]);
    expect(platformCalls, ['listen', 'cancel', 'listen']);
  });
}
