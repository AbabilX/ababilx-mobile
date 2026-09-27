import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ababilx/features/messages/data/local/chat_deletion_filter.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatDeletionFilter filter;
  final clear = <String, dynamic>{
    'conversation_id': 'chat',
    'message_id': '',
    'through_at': '2026-09-09T00:00:00.123456Z',
    'deleted_at': '2026-09-09T00:01:00Z',
    'entire_conversation': false,
  };
  ChatMessage message(String id, String at) => ChatMessage.fromJson({
    'id': id,
    'conversation_id': 'chat',
    'user_id': 'user',
    'body': 'old backup content',
    'created_at': at,
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    filter = ChatDeletionFilter();
    await filter.load('user');
    await filter.replace([clear]);
  });
  test('clear rejects old backup rows but preserves newer messages', () {
    expect(filter.allows(message('old', '2026-09-08T00:00:00Z')), false);
    expect(
      filter.allows(message('edge', '2026-09-09T00:00:00.123456Z')),
      false,
    );
    expect(filter.allows(message('new', '2026-09-09T00:00:00.123457Z')), true);
  });
  test('deletions survive restart and account switches', () async {
    final restored = ChatDeletionFilter();
    await restored.load('user');
    expect(restored.allows(message('old', '2026-09-08T00:00:00Z')), false);
    await restored.load('other');
    expect(restored.allows(message('old', '2026-09-08T00:00:00Z')), true);
  });
  test(
    'stale snapshot cannot undo clear and pending cutoff uses delete time',
    () async {
      await filter.replace([]);
      expect(filter.allows(message('old', '2026-09-08T00:00:00Z')), false);
      final queuedAt = DateTime.parse(
        '2026-09-09T00:00:30Z',
      ).microsecondsSinceEpoch;
      expect(filter.allowsTime('chat', queuedAt, pending: true), false);
      expect(filter.allowsTime('chat', queuedAt), true);
    },
  );
  test('individual deletion and group deletion reject later restore', () async {
    await filter.replace([
      {...clear, 'message_id': 'deleted', 'deleted_at': '2026-09-10T00:00:00Z'},
    ]);
    expect(filter.allows(message('deleted', '2026-09-10T00:00:00Z')), false);
    expect(filter.allows(message('other', '2026-09-10T00:00:00Z')), true);
    await filter.replace([
      {
        ...clear,
        'entire_conversation': true,
        'deleted_at': '2026-09-11T00:00:00Z',
      },
    ]);
    expect(filter.allows(message('later', '2026-09-12T00:00:00Z')), false);
  });
  group('local backup restore after a fresh start', () {
    // Delete chat at 09-01, then start fresh at 09-09 (0164 marker).
    final fresh = <String, dynamic>{
      ...clear,
      'explicit_through_at': '2026-09-01T00:00:00Z',
    };
    test('an old server keeps through_at as the only rule', () async {
      await filter.admitRestoredHistory();
      expect(filter.allows(message('old', '2026-09-05T00:00:00Z')), false);
    });
    test('restore sees past the watermark but not the delete', () async {
      await filter.replace([fresh]);
      expect(filter.allows(message('old', '2026-09-05T00:00:00Z')), false);
      await filter.admitRestoredHistory();
      expect(filter.allows(message('kept', '2026-09-05T00:00:00Z')), true);
      expect(filter.allows(message('deleted', '2026-08-30T00:00:00Z')), false);
      final reloaded = ChatDeletionFilter();
      await reloaded.load('user');
      expect(reloaded.allows(message('kept', '2026-09-05T00:00:00Z')), true);
    });
    test('a fresh start with no delete admits everything', () async {
      await filter.replace([
        {...clear, 'explicit_through_at': null},
      ]);
      await filter.admitRestoredHistory();
      expect(filter.allows(message('any', '2020-01-01T00:00:00Z')), true);
    });
    test(
      'the next fresh start or delete applies the watermark again',
      () async {
        await filter.replace([fresh]);
        await filter.admitRestoredHistory();
        await filter.replace([
          {
            ...fresh,
            'through_at': '2026-09-20T00:00:00Z',
            'deleted_at': '2026-09-20T00:00:00Z',
          },
        ]);
        expect(filter.allows(message('kept', '2026-09-05T00:00:00Z')), false);
      },
    );
    test('a whole-chat delete still wins', () async {
      await filter.replace([
        {...fresh, 'entire_conversation': true},
      ]);
      await filter.admitRestoredHistory();
      expect(filter.allows(message('kept', '2026-09-05T00:00:00Z')), false);
    });
  });
}
