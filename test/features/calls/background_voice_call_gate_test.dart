import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/native/background_voice_call_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 3, 12);

  VoiceCall call(String status, {String id = 'call-1'}) => VoiceCall(
    id: id,
    teamId: '',
    conversationId: 'conversation-1',
    callerId: 'caller-1',
    calleeId: 'callee-1',
    status: status,
    callerName: 'Caller',
    calleeName: 'Callee',
    expiresAt: now.add(const Duration(seconds: 30)),
    createdAt: now,
  );

  Map<String, dynamic> push({DateTime? expiresAt}) => {
    'call_id': 'call-1',
    'expires_at': (expiresAt ?? now.add(const Duration(seconds: 30)))
        .toIso8601String(),
  };

  Future<bool> no(String _) async => false;
  Future<bool> yes(String _) async => true;

  group('shouldPresent (local checks, no network)', () {
    test('never rings while this phone is in a call (busy rule)', () async {
      // The reported bug: answered, talking, then a late or repeated push for
      // the same call rang again and raised a second ringing screen.
      for (final live in ['call-1', 'other-call']) {
        final result = await BackgroundVoiceCallGate.shouldPresent(
          push(),
          now: now,
          endedLookup: no,
          answeredLookup: no,
          liveLookup: () async => live,
        );
        expect(result, isFalse, reason: 'live=$live');
      }
    });

    test('rings a fresh push', () async {
      final result = await BackgroundVoiceCallGate.shouldPresent(
        push(),
        now: now,
        endedLookup: no,
        answeredLookup: no,
      );
      expect(result, isTrue);
    });

    test('rejects a push with no call id', () async {
      final result = await BackgroundVoiceCallGate.shouldPresent(
        {'expires_at': now.add(const Duration(seconds: 30)).toIso8601String()},
        now: now,
        endedLookup: no,
        answeredLookup: no,
      );
      expect(result, isFalse);
    });

    test('rejects an expired push', () async {
      final result = await BackgroundVoiceCallGate.shouldPresent(
        push(expiresAt: now.subtract(const Duration(seconds: 1))),
        now: now,
        endedLookup: no,
        answeredLookup: no,
      );
      expect(result, isFalse);
    });

    test('rejects a call whose terminal push arrived first', () async {
      final result = await BackgroundVoiceCallGate.shouldPresent(
        push(),
        now: now,
        endedLookup: yes,
        answeredLookup: no,
      );
      expect(result, isFalse);
    });

    test('rejects a redelivered offer this device already answered', () async {
      final result = await BackgroundVoiceCallGate.shouldPresent(
        push(),
        now: now,
        endedLookup: no,
        answeredLookup: yes,
      );
      expect(result, isFalse);
    });
  });

  group('dismissIfOver (after the ring is up)', () {
    Future<List<String>> run(Future<VoiceCall> Function(String) lookup) async {
      final actions = <String>[];
      await BackgroundVoiceCallGate.dismissIfOver(
        'call-1',
        lookup: lookup,
        markEnded: (id) async => actions.add('mark:$id'),
        dismiss: (id) async => actions.add('dismiss:$id'),
      );
      return actions;
    }

    for (final status in [
      'cancelled',
      'declined',
      'missed',
      'ended',
      'failed',
    ]) {
      test('takes the ring down when the server says $status', () async {
        final actions = await run((_) async => call(status));
        expect(actions, ['mark:call-1', 'dismiss:call-1']);
      });
    }

    test('keeps ringing while the server says ringing', () async {
      expect(await run((_) async => call('ringing')), isEmpty);
    });

    test(
      'never ends an accepted call — it may be this device answering',
      () async {
        expect(await run((_) async => call('accepted')), isEmpty);
      },
    );

    test(
      'keeps ringing when the lookup fails (offline, 401, timeout)',
      () async {
        expect(await run((_) async => throw Exception('offline')), isEmpty);
      },
    );

    test('ignores an answer about a different call', () async {
      expect(await run((_) async => call('cancelled', id: 'other')), isEmpty);
    });
  });
}
