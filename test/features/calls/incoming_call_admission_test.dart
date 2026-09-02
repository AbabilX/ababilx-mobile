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
}
