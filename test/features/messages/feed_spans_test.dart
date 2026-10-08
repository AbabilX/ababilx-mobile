import 'package:ababilx/features/messages/data/local/feed_spans.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

int _ms(int minute) => DateTime.utc(
  2026,
  9,
  1,
).add(Duration(minutes: minute)).millisecondsSinceEpoch;

ChatMessage _msg(int minute, {int threadCount = 0}) => ChatMessage(
  id: 'm$minute',
  conversationId: 'c',
  userId: 'peer',
  body: 'b',
  threadCount: threadCount,
  createdAt: DateTime.utc(
    2026,
    9,
    1,
  ).add(Duration(minutes: minute)).toIso8601String(),
);

ChatMessagesPage _page(List<ChatMessage> rows, {bool hasMore = true}) =>
    ChatMessagesPage(
      messages: rows,
      nextCursor: hasMore ? rows.last.id : '',
      hasMore: hasMore,
    );

void main() {
  group('spanOfPage', () {
    test('vouches down to the oldest message without thread replies', () {
      final span = spanOfPage(
        _page([_msg(90), _msg(80), _msg(70)]),
        highMs: _ms(90),
      );
      expect(span.lowMs, _ms(70));
      expect(span.highMs, _ms(90));
      expect(span.cursor, 'm70');
      expect(span.done, isFalse);
    });

    test('a bumped thread root does not drag the proven range back', () {
      // m5 is months old and sits in this page only because of a new reply.
      final span = spanOfPage(
        _page([_msg(90), _msg(5, threadCount: 3), _msg(80)]),
        highMs: _ms(90),
      );
      expect(span.lowMs, _ms(80));
    });

    test('a page of nothing but thread roots proves no new range', () {
      final span = spanOfPage(
        _page([_msg(5, threadCount: 1), _msg(4, threadCount: 2)]),
        highMs: _ms(90),
      );
      expect(span.lowMs, _ms(90));
      expect(span.cursor, 'm4');
    });

    test('the last page proves everything below it', () {
      final span = spanOfPage(
        _page([_msg(3), _msg(2)], hasMore: false),
        highMs: _ms(90),
      );
      expect(span.lowMs, 0);
      expect(span.done, isTrue);
      expect(span.cursor, isEmpty);
    });
  });

  group('FeedSpans', () {
    FeedSpan span(int low, int high, {String cursor = '', bool done = false}) =>
        FeedSpan(
          lowMs: _ms(low),
          highMs: _ms(high),
          cursor: cursor,
          done: done,
        );

    test('an older page continues the stretch it was asked from', () {
      final spans = const FeedSpans()
          .add(span(70, 90, cursor: 'm70'))
          .add(span(40, 70, cursor: 'm40'));
      expect(spans.spans, hasLength(1));
      expect(spans.spans.single.lowMs, _ms(40));
      expect(spans.spans.single.highMs, _ms(90));
      expect(spans.spans.single.cursor, 'm40');
    });

    test('a newest page that reaches a proven stretch joins it', () {
      final spans = const FeedSpans()
          .add(span(10, 50, cursor: 'm10'))
          .add(span(45, 90, cursor: 'm45'));
      expect(spans.spans, hasLength(1));
      // The old end, and the cursor to go on from, are the deeper stretch's.
      expect(spans.spans.single.lowMs, _ms(10));
      expect(spans.spans.single.cursor, 'm10');
      expect(spans.spans.single.highMs, _ms(90));
    });

    test('a newest page that does not reach back leaves a hole', () {
      final spans = const FeedSpans()
          .add(span(10, 50, cursor: 'm10'))
          .add(span(70, 90, cursor: 'm70'));
      expect(spans.spans, hasLength(2));
      expect(spans.at(_ms(80))!.lowMs, _ms(70));
      expect(spans.at(_ms(60)), isNull);
      expect(spans.at(_ms(30))!.cursor, 'm10');
    });

    test('walking through the hole makes the two stretches one', () {
      final spans = const FeedSpans()
          .add(FeedSpan(lowMs: 0, highMs: _ms(50), done: true))
          .add(span(70, 90, cursor: 'm70'))
          .add(span(48, 70, cursor: 'm48'));
      expect(spans.spans, hasLength(1));
      expect(spans.spans.single.done, isTrue);
      expect(spans.spans.single.lowMs, 0);
      expect(spans.spans.single.highMs, _ms(90));
    });

    test('a page with no new range still moves the cursor on', () {
      final spans = const FeedSpans()
          .add(span(70, 90, cursor: 'm70'))
          .add(span(70, 70, cursor: 'root-4'));
      expect(spans.spans.single.cursor, 'root-4');
      expect(spans.spans.single.lowMs, _ms(70));
    });

    test('distrust ends the stretch at what is on screen', () {
      final spans = const FeedSpans()
          .add(FeedSpan(lowMs: 0, highMs: _ms(20), done: true))
          .add(span(40, 90, cursor: 'm40'))
          .distrustBelow(_ms(60), cursor: 'm60');
      expect(spans.spans, hasLength(1));
      expect(spans.spans.single.lowMs, _ms(60));
      expect(spans.spans.single.cursor, 'm60');
      expect(spans.spans.single.done, isFalse);
      expect(spans.at(_ms(10)), isNull);
    });

    test('survives a round trip, and garbage reads as nothing proven', () {
      final spans = const FeedSpans()
          .add(FeedSpan(lowMs: 0, highMs: _ms(20), done: true))
          .add(span(40, 90, cursor: 'm40'));
      final back = FeedSpans.decode(spans.encode());
      expect(back.spans, hasLength(2));
      expect(back.at(_ms(50))!.cursor, 'm40');
      expect(back.at(_ms(5))!.done, isTrue);
      expect(FeedSpans.decode('{not json').isEmpty, isTrue);
      expect(FeedSpans.decode('[{"l":9,"h":1}]').isEmpty, isTrue);
      expect(FeedSpans.decode(null).isEmpty, isTrue);
    });

    test('only the newest stretches are kept', () {
      var spans = const FeedSpans();
      for (var i = 0; i < 12; i++) {
        spans = spans.add(span(i * 100, i * 100 + 10, cursor: 'c$i'));
      }
      expect(spans.spans, hasLength(FeedSpans.maxSpans));
      expect(spans.spans.first.cursor, 'c11');
      expect(spans.at(_ms(5)), isNull);
    });
  });
}
