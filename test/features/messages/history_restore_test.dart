import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/history-restore/history_restore_flag.dart';
import 'package:ababilx/features/messages/history-restore/history_restore_job.dart';
import 'package:ababilx/features/messages/history-restore/history_restore_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChatConversation _conv(String id) => ChatConversation(
  id: id,
  teamId: '',
  type: 'dm',
  createdAt: '2026-09-01T10:00:00Z',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('skips chats already on disk or owned by an open timeline', () {
    expect(
      conversationIdsNeedingRestore(
        conversations: [_conv('a'), _conv('b'), _conv('c'), _conv('a')],
        alreadyOnDisk: {'a'},
        alreadyLive: {'c'},
      ),
      ['b'],
    );
  });

  test(
    'an explicit recovery can mark a finished restore pending again',
    () async {
      await HistoryRestoreFlag.mark('u1');
      expect(await HistoryRestoreFlag.isPending('u1'), isTrue);
      await HistoryRestoreFlag.complete('u1');
      expect(await HistoryRestoreFlag.isPending('u1'), isFalse);
      await HistoryRestoreFlag.mark('u1');
      expect(await HistoryRestoreFlag.isPending('u1'), isTrue);
    },
  );

  test(
    'sign-out clears the done bit so a later recovery can run once',
    () async {
      await HistoryRestoreFlag.mark('u1');
      await HistoryRestoreFlag.complete('u1');
      await HistoryRestoreFlag.clearAll();
      await HistoryRestoreFlag.mark('u1');
      expect(await HistoryRestoreFlag.isPending('u1'), isTrue);
    },
  );

  test('job reports every conversation even when one pull fails', () async {
    final pulled = <String>[];
    final progress = <(int, int)>[];
    await runHistoryRestore(
      ids: ['a', 'b', 'c'],
      concurrency: 2,
      pull: (id) async {
        pulled.add(id);
        if (id == 'b') throw StateError('nope');
      },
      onProgress: (done, total) => progress.add((done, total)),
      shouldStop: () => false,
    );
    expect(pulled.toSet(), {'a', 'b', 'c'});
    expect(progress.last, (3, 3));
  });
}
