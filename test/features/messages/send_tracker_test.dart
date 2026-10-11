import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/data/send_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(String id, MessageSendStatus status) => ChatMessage(
  id: id,
  conversationId: 'c1',
  userId: 'me',
  body: 'hi',
  createdAt: '2026-10-11T00:00:00Z',
  sendStatus: status,
  clientRef: id,
);

void main() {
  // A pending message is saved as "sending" before its request is made and
  // that row is never rewritten on failure. Read back, it showed "Sending…"
  // for good and could not be tapped to send again.
  test('a "sending" row nobody is sending reads back as failed', () {
    final tracker = SendTracker();
    final rows = tracker.settle([
      _message('a', MessageSendStatus.sending),
      _message('b', MessageSendStatus.sent),
    ]);
    expect(rows[0].sendStatus, MessageSendStatus.failed);
    expect(rows[1].sendStatus, MessageSendStatus.sent);
  });

  test('a send in flight is left alone, and released when it ends', () {
    final tracker = SendTracker()..begin('a');
    final live = [_message('a', MessageSendStatus.sending)];
    expect(tracker.settle(live).single.sendStatus, MessageSendStatus.sending);
    expect(identical(tracker.settle(live), live), isTrue);

    tracker.end('a', error: StateError('offline'));
    expect(tracker.settle(live).single.sendStatus, MessageSendStatus.failed);
    expect(tracker.errorOf('a'), isA<StateError>());
  });

  test('a new attempt forgets the last failure', () {
    final tracker = SendTracker()
      ..begin('a')
      ..end('a', error: StateError('first'))
      ..begin('a');
    expect(tracker.errorOf('a'), isNull);
    tracker.end('a');
    expect(tracker.errorOf('a'), isNull);
  });

  test('uploading and failed rows keep their state', () {
    final tracker = SendTracker();
    final rows = tracker.settle([
      _message('u', MessageSendStatus.uploading),
      _message('f', MessageSendStatus.failed),
    ]);
    expect(rows[0].sendStatus, MessageSendStatus.uploading);
    expect(rows[1].sendStatus, MessageSendStatus.failed);
  });
}
