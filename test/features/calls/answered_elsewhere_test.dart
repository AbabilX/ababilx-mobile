import 'package:ababilx/features/calls/native/answered_elsewhere.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a call answered on one device', () {
    test('leaves the device that answered it alone', () {
      // The push is addressed to the account, so it comes back to the answerer.
      expect(
        decideAnsweredElsewhere(answeredHere: true, ringingHere: false),
        AnsweredElsewhereAction.ignore,
      );
    });

    test('finishes the in-app ring on a device that did not answer', () {
      expect(
        decideAnsweredElsewhere(answeredHere: false, ringingHere: true),
        AnsweredElsewhereAction.finishRinging,
      );
    });

    test('dismisses the native surface when there is no local state', () {
      // A killed or dozing app rings from the FCM message alone.
      expect(
        decideAnsweredElsewhere(answeredHere: false, ringingHere: false),
        AnsweredElsewhereAction.dismissNative,
      );
    });

    test('answering wins over a ring this device has not torn down yet', () {
      expect(
        decideAnsweredElsewhere(answeredHere: true, ringingHere: true),
        AnsweredElsewhereAction.ignore,
      );
    });
  });
}
