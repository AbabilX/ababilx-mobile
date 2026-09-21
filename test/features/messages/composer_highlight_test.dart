import 'package:ababilx/features/messages/chat-timeline/composer_highlight_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _runs(String text, List<String> labels) => [
  for (final h in findComposerHighlights(text, labels))
    text.substring(h.start, h.end),
];

void main() {
  test('picked mentions and links paint, a typed @word does not', () {
    expect(
      _runs('hi @Sharmin Sorna see https://a.com and @bob', ['Sharmin Sorna']),
      ['@Sharmin Sorna', 'https://a.com'],
    );
  });

  test('an email is one run, never a mention inside it', () {
    expect(_runs('mail me@all.com @all', ['all']), ['me@all.com', '@all']);
  });

  test(
    'a spaced name is one run, and only where the send makes it a mention',
    () {
      const labels = ['Rabbani Prodhan', 'Rabbani'];
      expect(_runs('@Rabbani Prodhan, hi', labels), ['@Rabbani Prodhan']);
      expect(_runs('@Rabbani Prodhanx', ['Rabbani Prodhan']), isEmpty);
      expect(_runs('@Rabbani Pro', labels), ['@Rabbani']);
    },
  );

  testWidgets('a mention is drawn with non-breaking spaces', (tester) async {
    final ctrl = ComposerHighlightController(
      text: 'hey @Rabbani Prodhan ok',
      mentionLabels: () => ['Rabbani Prodhan'],
    );
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = ctrl.buildTextSpan(context: context, withComposing: false);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(span.toPlainText(), 'hey @Rabbani\u00A0Prodhan ok');
    expect(span.toPlainText().length, ctrl.text.length);
  });
}
