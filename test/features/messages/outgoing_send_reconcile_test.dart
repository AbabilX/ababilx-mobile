import 'dart:async';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:ababilx/features/messages/data/chat_message_merge.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_sidebar_cache.dart'
    show chatLocalDbProvider;
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _conversationId = 'conversation-1';
const _clientRef = 'client-ref-1';
const _serverId = 'server-id-1';

/// The server echoes `client_message_id` back on the confirmed message, so the
/// server copy carries the same [clientRef] as the local bubble it settles.
ChatMessage _serverCopy() => ChatMessage(
  id: _serverId,
  conversationId: _conversationId,
  userId: 'me',
  body: 'hello',
  createdAt: '2026-09-03T10:00:01Z',
  clientRef: _clientRef,
);

class _FakeRepo extends ChatRepository {
  _FakeRepo() : super(ApiClient(const SecureStorage(FlutterSecureStorage())));

  final sendCall = Completer<ChatMessage>();

  @override
  Future<ChatMessage> sendMessage(
    String conversationId, {
    required String clientMessageId,
    required String body,
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionVersion,
    int? encryptionKeyVersion,
    String? parentId,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
  }) => sendCall.future;

  @override
  Future<void> acknowledgeMessages(
    String status,
    List<String> messageIds,
  ) async {}

  @override
  Future<void> markRead(String conversationId) async {}
}

class _ReconcileNotifier extends ChatNotifier {
  _ReconcileNotifier(this._fakeRepo);

  final _FakeRepo _fakeRepo;

  @override
  ChatRepository get repo => _fakeRepo;

  @override
  Future<String> ensureCurrentUserId() async => 'me';

  @override
  Future<void> fetchSidebarSilent() async {}

  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    activeConversationId: _conversationId,
    feeds: {
      feedKey(_conversationId): const ChatFeed(messages: [], fetchedAt: 1),
    },
  );
}

void main() {
  late ChatLocalDb db;
  late _FakeRepo repo;
  late ProviderContainer container;

  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [
        chatLocalDbProvider.overrideWithValue(db),
        chatProvider.overrideWith(() => _ReconcileNotifier(repo)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  List<ChatMessage> feedMessages() =>
      container.read(chatProvider).feedFor(_conversationId).messages;

  test(
    'a websocket confirm before the http response leaves one sent message',
    () async {
      final notifier = container.read(chatProvider.notifier);
      final send = notifier.sendMessage(
        conversationId: _conversationId,
        body: 'hello',
        clientMessageId: _clientRef,
      );
      // Let the pending bubble land before anything settles it.
      await Future<void>.delayed(Duration.zero);
      expect(feedMessages().single.id, _clientRef);

      notifier.handleWsEvent({
        'type': 'chat.message.created',
        'conversation_id': _conversationId,
        'message': _serverCopy().toJson(),
      });
      await Future<void>.delayed(Duration.zero);
      expect(feedMessages().single.id, _serverId);

      // The http response settles the same send a second time. Matching on
      // clientRef here used to delete the confirmed row, emptying the chat
      // window while the sidebar preview stayed correct.
      repo.sendCall.complete(_serverCopy());
      await send;

      final messages = feedMessages();
      expect(messages, hasLength(1));
      expect(messages.single.id, _serverId);
      expect(messages.single.sendStatus, MessageSendStatus.sent);
    },
  );

  test('the http response alone settles the pending bubble', () async {
    final notifier = container.read(chatProvider.notifier);
    final send = notifier.sendMessage(
      conversationId: _conversationId,
      body: 'hello',
      clientMessageId: _clientRef,
    );
    await Future<void>.delayed(Duration.zero);
    repo.sendCall.complete(_serverCopy());
    await send;

    final messages = feedMessages();
    expect(messages, hasLength(1));
    expect(messages.single.id, _serverId);
    expect(messages.single.sendStatus, MessageSendStatus.sent);
  });

  test(
    'a lost response never marks a socket-confirmed message failed',
    () async {
      final notifier = container.read(chatProvider.notifier);
      final send = notifier.sendMessage(
        conversationId: _conversationId,
        body: 'hello',
        clientMessageId: _clientRef,
      );
      await Future<void>.delayed(Duration.zero);

      notifier.handleWsEvent({
        'type': 'chat.message.created',
        'conversation_id': _conversationId,
        'message': _serverCopy().toJson(),
      });
      await Future<void>.delayed(Duration.zero);

      // The server committed and broadcast, then the response was lost.
      repo.sendCall.completeError(StateError('network gone'));
      await send;

      final messages = feedMessages();
      expect(messages, hasLength(1));
      expect(messages.single.sendStatus, MessageSendStatus.sent);
    },
  );

  test('canonical merge collapses a bubble and its server copy', () {
    final pending = ChatMessage(
      id: _clientRef,
      conversationId: _conversationId,
      userId: 'me',
      body: 'hello',
      createdAt: '2026-09-03T10:00:00Z',
      sendStatus: MessageSendStatus.sending,
      clientRef: _clientRef,
    );

    final merged = canonicalChatMessages([pending, _serverCopy()]);

    expect(merged, hasLength(1));
    expect(merged.single.id, _serverId);
  });

  test('canonical merge keeps a bubble that has no server copy yet', () {
    final pending = ChatMessage(
      id: _clientRef,
      conversationId: _conversationId,
      userId: 'me',
      body: 'hello',
      createdAt: '2026-09-03T10:00:00Z',
      sendStatus: MessageSendStatus.sending,
      clientRef: _clientRef,
    );

    expect(canonicalChatMessages([pending]).single.id, _clientRef);
  });

  test('an incoming live event and a history clone stay one row', () async {
    final notifier = container.read(chatProvider.notifier);
    notifier.handleWsEvent({
      'type': 'chat.message.created',
      'conversation_id': _conversationId,
      'message': ChatMessage(
        id: 'server-peer',
        conversationId: _conversationId,
        userId: 'peer',
        userName: 'Peer',
        body: 'hello',
        createdAt: '2026-09-03T10:00:01Z',
        clientRef: 'peer-client',
      ).toJson(),
    });
    await Future<void>.delayed(Duration.zero);
    expect(feedMessages(), hasLength(1));

    notifier.handleWsEvent({
      'type': 'chat.message.created',
      'conversation_id': _conversationId,
      'message': ChatMessage(
        id: 'server-peer',
        conversationId: _conversationId,
        userId: 'peer',
        userName: 'Peer',
        body: 'hello',
        createdAt: '2026-09-03T10:00:01Z',
      ).toJson(),
    });
    await Future<void>.delayed(Duration.zero);
    expect(feedMessages(), hasLength(1));
  });
}
