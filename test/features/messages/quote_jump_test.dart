import 'package:ababilx/features/messages/chat-timeline/message_bubble.dart';
import 'package:ababilx/features/messages/chat-timeline/message_quote_block.dart';
import 'package:ababilx/features/messages/chat-timeline/quoted_bubble_layout.dart';
import 'package:ababilx/features/messages/chat-timeline/timeline_jump.dart';
import 'package:ababilx/features/messages/chat-timeline/timeline_jump_target.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _sized(double width, {Key? key}) =>
    SizedBox(key: key, width: width, height: 20);

Future<Size> _layout(
  WidgetTester tester, {
  required Widget quote,
  required Widget content,
  double maxWidth = 400,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: QuotedBubbleLayout(quote: quote, content: content),
        ),
      ),
    ),
  );
  return tester.getSize(find.byType(QuotedBubbleLayout));
}

BubbleColors _colors() => const BubbleColors(
  background: Color(0xFF202020),
  foreground: Color(0xFFFFFFFF),
  muted: Color(0xFF999999),
);

void main() {
  group('a quote is as wide as the message under it', () {
    testWidgets('and is stretched to it when the body is wider', (
      tester,
    ) async {
      const quoteKey = Key('quote');
      final size = await _layout(
        tester,
        quote: _sized(60, key: quoteKey),
        content: _sized(300),
      );

      expect(size.width, 300);
      expect(tester.getSize(find.byKey(quoteKey)).width, 300);
    });

    testWidgets('and never drags the bubble out past its own ask', (
      tester,
    ) async {
      // A long quoted line would take the whole 400 on its own; the reply
      // under it is two words. Before this layout that bubble was full width.
      final size = await _layout(
        tester,
        quote: const Text('a very long quoted line that would fill the bubble'),
        content: _sized(90),
      );

      expect(size.width, lessThan(240));
      expect(size.width, greaterThan(90));
    });

    testWidgets('and asks for nothing when it is short', (tester) async {
      final size = await _layout(
        tester,
        quote: _sized(40),
        content: _sized(120),
      );

      expect(size.width, 120);
    });
  });

  group('tapping a quote', () {
    late ScrollController scroll;
    late TimelineJumpController jump;

    Widget app({int count = 40}) {
      return MaterialApp(
        home: TimelineJumpScope(
          controller: jump,
          child: Scaffold(
            body: ListView.builder(
              controller: scroll,
              reverse: true,
              itemCount: count,
              itemBuilder: (context, i) {
                final index = count - 1 - i;
                return TimelineJumpTarget(
                  messageId: 'm$index',
                  child: SizedBox(
                    height: 120,
                    child: index == count - 1
                        ? MessageQuoteBlock(
                            quote: const ChatMessageQuote(
                              messageId: 'm0',
                              userId: 'u1',
                              userName: 'Alvi',
                              body: 'the first message',
                            ),
                            colors: _colors(),
                            isOwn: false,
                          )
                        : Text('m$index'),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    setUp(() {
      scroll = ScrollController();
      jump = TimelineJumpController(scroll: scroll, loadOlder: () async {});
    });

    tearDown(() => scroll.dispose());

    testWidgets('walks the list back to the message it answers', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      expect(find.text('m0'), findsNothing);

      await tester.tap(find.text('Alvi'));
      await tester.pumpAndSettle();

      expect(find.text('m0'), findsOneWidget);
      expect(jump.highlighted.value, 'm0');

      // Let the highlight expire rather than leaving its timer pending.
      await tester.pump(const Duration(seconds: 2));
      expect(jump.highlighted.value, isNull);
      jump.dispose();
    });

    testWidgets('puts the list back when there is nothing to reach', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimelineJumpScope(
            controller: jump,
            child: Scaffold(
              body: ListView.builder(
                controller: scroll,
                reverse: true,
                itemCount: 30,
                itemBuilder: (context, i) => TimelineJumpTarget(
                  messageId: 'k$i',
                  child: const SizedBox(height: 120, child: Text('row')),
                ),
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(200);
      await tester.pump();

      // Started, not awaited: the walk waits for frames, and only the test
      // pumps them.
      final walk = jump.jumpTo('missing');
      await tester.pumpAndSettle();
      expect(await walk, isFalse);
      expect(scroll.position.pixels, 200);
      jump.dispose();
    });
  });
}
