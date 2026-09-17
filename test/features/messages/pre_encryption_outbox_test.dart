import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_outbox_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_sidebar_cache.dart';
import 'package:ababilx/features/messages/data/local/local_outbox_cipher.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const storage = SecureStorage(FlutterSecureStorage());

class OfflineVault extends MessageVault {
  OfflineVault() : super(ChatRepository(ApiClient(storage)), storage);
  @override
  Future<EncryptedDmPayload> encryptNew({
    required String conversationId,
    required String text,
    required String currentUserId,
  }) async => throw StateError('offline before key lookup');
}

class TestChat extends ChatNotifier {
  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    dms: [
      ChatConversation.fromJson({'id': 'chat', 'type': 'dm'}),
    ],
  );
  @override
  Future<String> ensureCurrentUserId() async => 'me';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'encryption failure survives restart with full retry payload and no plaintext on disk',
    () async {
      final db = ChatLocalDb.forTesting(NativeDatabase.memory());
      ProviderContainer open() => ProviderContainer(
        overrides: [
          chatLocalDbProvider.overrideWithValue(db),
          messageVaultProvider.overrideWithValue(OfflineVault()),
          chatProvider.overrideWith(TestChat.new),
        ],
      );
      var container = open();
      final sent = await container
          .read(chatProvider.notifier)
          .sendMessage(
            conversationId: 'chat',
            body: 'private message',
            clientMessageId: 'send-1',
            quotedMessageId: 'quoted-1',
            mentionedUserIds: ['peer'],
          );
      expect(sent, isNull);
      final entries = await ChatOutboxCache(db).readAll();
      expect(entries, hasLength(1));
      expect(entries.single.body, isEmpty);
      expect(entries.single.encryptedBody, isNot(contains('private message')));
      container.dispose();
      container = open();
      await container.read(chatProvider.notifier).hydrateOutboxMessages();
      final restored = container
          .read(chatProvider)
          .feedFor('chat')
          .messages
          .single;
      expect(restored.body, 'private message');
      expect(restored.clientRef, 'send-1');
      expect(restored.pendingQuotedMessageId, 'quoted-1');
      expect(restored.pendingMentionedUserIds, ['peer']);
      expect(restored.sendStatus, MessageSendStatus.failed);
      await expectLater(
        LocalOutboxCipher(storage).open(
          entries.single.encryptedBody!,
          'other-account',
          'chat',
          'send-1',
        ),
        throwsA(anything),
      );
      await ChatOutboxCache(db).removeConversation('chat');
      expect(await ChatOutboxCache(db).readAll(), isEmpty);
      container.dispose();
      await db.close();
    },
  );
}
