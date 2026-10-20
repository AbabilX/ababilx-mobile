import 'package:ababilx/features/home/catch-up/catch_up_preview.dart';
import 'package:ababilx/features/home/catch-up/catch_up_queue.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advances mark-read and keep-unread, undoes in reverse', () {
    final q = CatchUpQueue(['a', 'b', 'c']);
    expect(q.left, 3);
    expect(q.current, 'a');

    q.advance(CatchUpStep.markedRead);
    expect(q.current, 'b');
    expect(q.left, 2);
    expect(q.behind(), ['c']);

    q.advance(CatchUpStep.keptUnread);
    expect(q.current, 'c');
    expect(q.canUndo, isTrue);

    expect(q.revert(), CatchUpStep.keptUnread);
    expect(q.current, 'b');
    expect(q.revert(), CatchUpStep.markedRead);
    expect(q.current, 'a');
    expect(q.revert(), isNull);
  });

  test('empty deck is a no-op', () {
    final q = CatchUpQueue([]);
    expect(q.isEmpty, isTrue);
    q.advance(CatchUpStep.markedRead);
    expect(q.revert(), isNull);
  });

  test('a line is the plain body, and mine drops the other name', () {
    final mine = catchUpLine(
      const ChatMessage(
        id: '1',
        conversationId: 'c',
        userId: 'me',
        body: 'hello there',
        createdAt: '2026-10-20T10:00:00Z',
        userName: 'Me',
      ),
      'me',
    );
    expect(mine.mine, isTrue);
    expect(mine.text, 'hello there');

    final theirs = catchUpLine(
      const ChatMessage(
        id: '2',
        conversationId: 'c',
        userId: 'them',
        body: 'photo incoming',
        createdAt: '2026-10-20T10:01:00Z',
        userName: 'Lisa',
      ),
      'me',
    );
    expect(theirs.mine, isFalse);
    expect(theirs.name, 'Lisa');
    expect(theirs.text, 'photo incoming');
  });
}
