import 'package:ababilx/features/calls/native/incoming_call_admission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows a call only when no native call exists', () {
    expect(
      decideIncomingCallAdmission('call-1', const []),
      IncomingCallAdmission.show,
    );
  });

  test('restores tone for the same still-ringing call', () {
    expect(
      decideIncomingCallAdmission('call-1', const [
        NativeCallSnapshot(id: 'call-1', isAccepted: false),
      ]),
      IncomingCallAdmission.restoreRinging,
    );
  });

  test('never re-rings the same accepted call', () {
    expect(
      decideIncomingCallAdmission('call-1', const [
        NativeCallSnapshot(id: 'call-1', isAccepted: true),
      ]),
      IncomingCallAdmission.ignoreAccepted,
    );
  });

  test('does not ring a second call while another call is active', () {
    expect(
      decideIncomingCallAdmission('call-2', const [
        NativeCallSnapshot(id: 'call-1', isAccepted: true),
      ]),
      IncomingCallAdmission.ignoreBusy,
    );
  });

  group('nativeCallWasAccepted', () {
    test(
      'reports the Accept CallKit recorded while Flutter was backgrounded',
      () {
        expect(
          nativeCallWasAccepted('call-1', const [
            NativeCallSnapshot(id: 'call-1', isAccepted: true),
          ]),
          isTrue,
        );
      },
    );

    test('a still-ringing record is not an accept', () {
      expect(
        nativeCallWasAccepted('call-1', const [
          NativeCallSnapshot(id: 'call-1', isAccepted: false),
        ]),
        isFalse,
      );
    });

    test('another call being accepted says nothing about this one', () {
      expect(
        nativeCallWasAccepted('call-1', const [
          NativeCallSnapshot(id: 'call-2', isAccepted: true),
        ]),
        isFalse,
      );
    });

    test('no id and no records are both false, never a stray adopt', () {
      expect(
        nativeCallWasAccepted('', const [
          NativeCallSnapshot(id: '', isAccepted: true),
        ]),
        isFalse,
      );
      expect(nativeCallWasAccepted('call-1', const []), isFalse);
    });
  });
}
