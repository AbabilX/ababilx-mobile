import 'package:ababilx/features/messages/chat-timeline/message_long_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageLongBody.isLong', () {
    test('an ordinary message is not long', () {
      expect(MessageLongBody.isLong('Ready for standup in five.'), isFalse);
    });

    test('a body past the character cap is long', () {
      expect(MessageLongBody.isLong('a' * 901), isTrue);
      expect(MessageLongBody.isLong('a' * 900), isFalse);
    });

    test('a short but tall body is long', () {
      // A stack trace or an ASCII table is well under the character cap and
      // still taller than the screen, which is the case that made the
      // long-press overlay unreadable.
      expect(MessageLongBody.isLong(List.filled(14, 'x').join('\n')), isTrue);
      expect(MessageLongBody.isLong(List.filled(13, 'x').join('\n')), isFalse);
    });

    test('an empty body is never long', () {
      expect(MessageLongBody.isLong(''), isFalse);
    });

    test('trailing blank lines still count as lines', () {
      expect(MessageLongBody.isLong('x${'\n' * 13}'), isTrue);
    });
  });

  testWidgets('collapsed body does not create a GPU shader layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CollapsedBodyFade(
              child: Text(
                'A long message body that is clipped before Read more.\n'
                'The Android renderer must not composite it through a shader.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.layers.whereType<ShaderMaskLayer>(),
      isEmpty,
      reason:
          'ShaderMask over the clipped long-message scroll layer produces '
          'the diagonal raster artefact seen on Android.',
    );
  });
}
