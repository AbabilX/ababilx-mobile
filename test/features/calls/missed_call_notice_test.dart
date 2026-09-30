import 'package:ababilx/features/calls/native/missed_call_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('javaStringHashCode matches java.lang.String.hashCode()', () {
    test('small positive', () {
      expect(javaStringHashCode('hello'), 99162322);
    });

    test('wraps to a negative int', () {
      expect(javaStringHashCode('Hello World'), -862545276);
    });

    test('empty string', () {
      expect(javaStringHashCode(''), 0);
    });
  });

  test('missed-call id is CallKit\'s "missing_<call id>" hash', () {
    expect(
      missedCallNotificationId('7d3f1c2e-9b4a-4f6e-8a1d-2c5b6e7f8a90'),
      1105921929,
    );
  });

  group('applies', () {
    test('only the callee copy the server marked missed', () {
      expect(
        MissedCallNotice.applies({
          'type': 'voice_call_ended',
          'missed_call': '1',
          'call_id': 'c',
        }),
        isTrue,
      );
    });

    test('not a plain stop-ringing push', () {
      expect(
        MissedCallNotice.applies({'type': 'voice_call_ended', 'call_id': 'c'}),
        isFalse,
      );
    });

    test('not without a call id', () {
      expect(
        MissedCallNotice.applies({
          'type': 'voice_call_ended',
          'missed_call': '1',
        }),
        isFalse,
      );
    });

    test('not another push type', () {
      expect(
        MissedCallNotice.applies({
          'type': 'voice_call',
          'missed_call': '1',
          'call_id': 'c',
        }),
        isFalse,
      );
    });
  });
}
