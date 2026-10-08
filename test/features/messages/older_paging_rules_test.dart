import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/older_paging_rules.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg(
  int minute, {
  int threadCount = 0,
  bool privateChat = false,
  bool pending = false,
  int revision = 0,
  ChatDeliverySummary? delivery,
}) => ChatMessage(
  id: 'm$minute',
  conversationId: 'c',
  userId: 'peer',
  body: 'b',
  threadCount: threadCount,
  privateChat: privateChat,
  revision: revision,
  delivery: delivery,
  sendStatus: pending ? MessageSendStatus.sending : MessageSendStatus.sent,
  createdAt: DateTime.utc(
    2026,
    9,
    1,
  ).add(Duration(minutes: minute)).toIso8601String(),
);

const _read = ChatDeliverySummary(
  targetedDevices: 1,
  deliveredDevices: 1,
  readDevices: 1,
);

void main() {
  group('olderAnchors', () {
    test('the oldest message without thread replies comes first', () {
      final anchors = olderAnchors([_msg(1, threadCount: 2), _msg(2), _msg(3)]);
      expect(anchors.map((m) => m.id), ['m2', 'm3']);
    });

    test('never an unsent bubble or a private-chat message', () {
      final anchors = olderAnchors([
        _msg(1, privateChat: true),
        _msg(2, pending: true),
        _msg(3, threadCount: 1),
      ]);
      // The server lets a private message go; its id would answer "empty".
      expect(anchors.map((m) => m.id), ['m3']);
    });

    test('nothing to stand on is an honest empty list', () {
      expect(olderAnchors([_msg(1, privateChat: true)]), isEmpty);
    });
  });

  group('fromCut', () {
    final cut = DateTime.utc(2026, 9, 1, 0, 10).millisecondsSinceEpoch;

    test('a thread root older than the cut waits for its own place', () {
      final shown = fromCut([_msg(2, threadCount: 4), _msg(10), _msg(20)], cut);
      expect(shown.map((m) => m.id), ['m10', 'm20']);
    });

    test('an unsent bubble always stays', () {
      final shown = fromCut([_msg(1, pending: true), _msg(20)], cut);
      expect(shown.map((m) => m.id), ['m1', 'm20']);
    });

    test('no cut hides nothing', () {
      expect(fromCut([_msg(2), _msg(20)], 0), hasLength(2));
    });
  });

  group('worthRefreshing', () {
    test('recent pages are checked, old history is taken as stored', () {
      final now = DateTime.utc(2026, 9, 1).add(const Duration(days: 40));
      expect(worthRefreshing(_msg(0), now), isFalse);
      expect(
        worthRefreshing(_msg(0), now.subtract(const Duration(days: 20))),
        isTrue,
      );
    });
  });

  group('compareServerCopy', () {
    test('a message the phone never had is newer', () {
      expect(compareServerCopy(null, _msg(1)), ServerCopy.newer);
    });

    test('a higher server revision is newer; a lower one is ignored', () {
      expect(
        compareServerCopy(_msg(1, revision: 4), _msg(1, revision: 9)),
        ServerCopy.newer,
      );
      // A socket update landed after this page was read on the server.
      expect(
        compareServerCopy(_msg(1, revision: 9), _msg(1, revision: 4)),
        ServerCopy.same,
      );
    });

    test('same revision, moved receipts: only the ticks change', () {
      expect(
        compareServerCopy(
          _msg(1, revision: 4),
          _msg(1, revision: 4, delivery: _read),
        ),
        ServerCopy.receipts,
      );
      expect(
        compareServerCopy(
          _msg(1, revision: 4, delivery: _read),
          _msg(1, revision: 4, delivery: _read),
        ),
        ServerCopy.same,
      );
    });

    test('a send still in flight is left to the send path', () {
      expect(
        compareServerCopy(_msg(1, pending: true), _msg(1, revision: 9)),
        ServerCopy.same,
      );
    });
  });
}
