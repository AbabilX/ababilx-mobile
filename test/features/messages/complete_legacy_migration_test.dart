import 'dart:async';
import 'dart:convert';
import 'package:ababilx/features/messages/data/local/android_chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/drift_chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ababilx.app/chat_store');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final thread in <String?>[null, 'root']) {
    test(
      'migrates every page and repairs old markers (thread=$thread)',
      () async {
        final db = ChatLocalDb.forTesting(NativeDatabase.memory());
        final legacy = DriftChatMessageStore(db, keepPerConversation: 200000);
        final rows = List.generate(
          4001,
          (i) => ChatMessage(
            id: 'm${i.toString().padLeft(5, '0')}',
            clientRef: 'r${i.toString().padLeft(5, '0')}',
            conversationId: 'c',
            userId: 'u',
            body: 'history',
            parentId: thread,
            createdAt: '2026-10-01T00:00:00Z',
          ),
        );
        await legacy.saveAllOrThrow(rows);
        final held = <String, String>{};
        final batches = <int>[];
        final finished = Completer<void>();
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isLegacyMigrated') {
            // The old marker is present, but must not suppress repair.
            return call.arguments['scope'] == jsonEncode(['c', thread]);
          }
          if (call.method == 'upsert') {
            final batch = call.arguments['rows'] as List;
            batches.add(batch.length);
            for (final row in batch) {
              expect(row['recoverySource'], 'backup');
              held[row['id'] as String] = row['payloadJson'] as String;
            }
          }
          if (call.method == 'migrateLegacy') {
            expect(call.arguments['rows'], isEmpty);
            expect(held, hasLength(4001));
            finished.complete();
          }
          if (call.method == 'page') return [held['r00000']!];
          return null;
        });
        try {
          final store = ChatMessageStore(
            db,
            androidStore: const AndroidChatMessageStore(),
          );
          await store.page('c', threadRootId: thread);
          await finished.future.timeout(const Duration(seconds: 10));
          await Future<void>.delayed(Duration.zero);
          expect(batches, [2000, 2000, 1]);
          expect(
            (await store.page('c', threadRootId: thread)).single.id,
            'm00000',
          );
        } finally {
          messenger.setMockMethodCallHandler(channel, null);
          await db.close();
        }
      },
    );
  }

  test(
    'failed batch leaves scope incomplete and the next read retries',
    () async {
      final db = ChatLocalDb.forTesting(NativeDatabase.memory());
      final legacy = DriftChatMessageStore(db, keepPerConversation: 200000);
      await legacy.saveAllOrThrow([
        const ChatMessage(
          id: 'm',
          conversationId: 'c',
          userId: 'u',
          body: '',
          createdAt: '2026-10-01T00:00:00Z',
        ),
      ]);
      var attempts = 0;
      var marks = 0;
      final failed = Completer<void>();
      final finished = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isLegacyMigrated') return false;
        if (call.method == 'upsert' && ++attempts == 1) {
          failed.complete();
          throw PlatformException(code: 'disk');
        }
        if (call.method == 'migrateLegacy') {
          marks++;
          finished.complete();
        }
        return null;
      });
      try {
        final store = ChatMessageStore(
          db,
          androidStore: const AndroidChatMessageStore(),
        );
        await store.page('c');
        await failed.future;
        await Future<void>.delayed(Duration.zero);
        expect(marks, 0);
        await store.page('c');
        await finished.future.timeout(const Duration(seconds: 5));
        expect(marks, 1);
        expect(attempts, 2);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        await db.close();
      }
    },
  );
}
