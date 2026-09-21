import 'dart:async';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/chat_sidebar_cache.dart'
    show chatLocalDbProvider;
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _open = 'conv-open';
const _other = 'conv-other';
const _root = 'root-1';

ChatMessage _msg(
  String id, {
  String conversationId = _open,
  int second = 0,
  int minute = 0,
  String? parentId,
  String userId = 'peer',
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  userId: userId,
  body: 'body $id',
  parentId: parentId,
  createdAt: DateTime.utc(2026, 9, 20, 10, minute, second).toIso8601String(),
);

/// A server that can be unplugged or made to hang.
class _Repo extends ChatRepository {
  _Repo() : super(ApiClient(const SecureStorage(FlutterSecureStorage())));

  bool offline = false;
  Completer<ChatMessagesPage>? hang;
  ChatMessagesPage page = const ChatMessagesPage(
    messages: [],
    nextCursor: '',
    hasMore: false,
  );
  int listCalls = 0;

  @override
  Future<ChatMessagesPage> listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
    String? thread,
  }) async {
    listCalls++;
    if (offline) throw StateError('network unreachable');
    final pending = hang;
    if (pending != null) return pending.future;
    return page;
  }

  @override
  Future<void> acknowledgeMessages(
    String status,
    List<String> messageIds,
  ) async {}

  @override
  Future<void> markRead(String conversationId) async {}
}

/// The durable store with gates on its reads and writes, so a test can hold a
/// disk read or a socket write open while something else happens.
class _GatedStore extends ChatMessageStore {
  _GatedStore(super.db);

  Completer<void>? readGate;
  Completer<void>? writeGate;
  int pageReads = 0;

  @override
  Future<List<ChatMessage>> page(
    String conversationId, {
    int limit = diskPageSize,
    int? beforeMs,
    String? beforeId,
    String? threadRootId,
  }) async {
    pageReads++;
    final gate = readGate;
    if (gate != null) await gate.future;
    return super.page(
      conversationId,
      limit: limit,
      beforeMs: beforeMs,
      beforeId: beforeId,
      threadRootId: threadRootId,
    );
  }

  @override
  Future<void> saveAll(List<ChatMessage> messages) async {
    final gate = writeGate;
    if (gate != null) await gate.future;
    return super.saveAll(messages);
  }
}

class _Notifier extends ChatNotifier {
  _Notifier(this._fake);

  final _Repo _fake;

  @override
  ChatRepository get repo => _fake;

  @override
  Future<String> ensureCurrentUserId() async => 'me';

  @override
  Future<void> fetchSidebarSilent() async {}

  @override
  ChatState build() {
    super.build();
    return const ChatState(
      currentUserId: 'me',
      dms: [
        ChatConversation(id: _open, teamId: '', type: 'dm', createdAt: ''),
        ChatConversation(id: _other, teamId: '', type: 'dm', createdAt: ''),
      ],
    );
  }
}

void main() {
  late ChatLocalDb db;
  late _GatedStore store;
  late _Repo repo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    store = _GatedStore(db);
    repo = _Repo();
    container = ProviderContainer(
      overrides: [
        chatLocalDbProvider.overrideWithValue(db),
        chatMessageStoreProvider.overrideWithValue(store),
        chatProvider.overrideWith(() => _Notifier(repo)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ChatNotifier notifier() => container.read(chatProvider.notifier);
  ChatFeed feed(String id, {String? thread}) =>
      container.read(chatProvider).feedFor(id, threadRootId: thread);
  List<String> ids(String id, {String? thread}) =>
      feed(id, thread: thread).messages.map((m) => m.id).toList();

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void socket(ChatMessage message) => notifier().handleWsEvent({
    'type': 'chat.message.created',
    'conversation_id': message.conversationId,
    'message': message.toJson(),
  });

  test(
    'a cold cached open paints the disk page while the network hangs',
    () async {
      await store.saveAll([_msg('a', second: 1), _msg('b', second: 2)]);
      repo.hang = Completer<ChatMessagesPage>();
      final painted = await notifier().hydrateFeedFromCache(_open);
      unawaited(notifier().loadFeed(_open, force: true));
      await settle();

      expect(painted, isTrue);
      expect(ids(_open), ['a', 'b']);
      expect(feed(_open).loading, isFalse);
    },
  );

  test('a message received for an unopened DM is on screen at open, before its '
      'disk write lands', () async {
    store.writeGate = Completer<void>();
    socket(_msg('live', conversationId: _other, second: 5));
    await settle();

    await notifier().hydrateFeedFromCache(_other);

    expect(ids(_other), ['live']);
    store.writeGate!.complete();
  });

  test('a message arriving while the disk page is read is not lost', () async {
    await store.saveAll([_msg('old', second: 1)]);
    store.readGate = Completer<void>();

    final hydrate = notifier().hydrateFeedFromCache(_open);
    await settle();
    socket(_msg('mid', second: 9));
    await settle();
    store.readGate!.complete();
    await hydrate;

    expect(ids(_open), ['old', 'mid']);
  });

  test('two opens of one feed read the disk once', () async {
    await store.saveAll([_msg('a', second: 1)]);
    store.readGate = Completer<void>();
    final reads = store.pageReads;

    final first = notifier().hydrateFeedFromCache(_open);
    final second = notifier().hydrateFeedFromCache(_open);
    store.readGate!.complete();
    await Future.wait([first, second]);

    expect(store.pageReads - reads, 1);
    expect(ids(_open), ['a']);
  });

  test(
    'a network page that lands during the disk read keeps its cursor',
    () async {
      await store.saveAll([_msg('a', second: 1)]);
      store.readGate = Completer<void>();
      repo.page = ChatMessagesPage(
        messages: [_msg('a', second: 1), _msg('b', second: 2)],
        nextCursor: 'cursor-1',
        hasMore: true,
      );

      final hydrate = notifier().hydrateFeedFromCache(_open);
      await settle();
      // The network refresh is not allowed to wait on the disk read.
      final network = notifier().loadFeed(_open, force: true);
      await settle();
      store.readGate!.complete();
      await Future.wait([hydrate, network]);

      expect(ids(_open), ['a', 'b']);
      expect(feed(_open).nextCursor, 'cursor-1');
      expect(feed(_open).fetchedAt, greaterThan(0));
    },
  );

  test('a message deleted while the disk page is read stays deleted', () async {
    await store.saveAll([_msg('keep', second: 1), _msg('gone', second: 2)]);
    store.readGate = Completer<void>();

    final hydrate = notifier().hydrateFeedFromCache(_open);
    await settle();
    notifier().handleWsEvent({
      'type': 'chat.message.deleted',
      'conversation_id': _open,
      'id': 'gone',
    });
    await settle();
    store.readGate!.complete();
    await hydrate;

    expect(ids(_open), ['keep']);
  });

  test('a thread opens from disk offline and pages back offline', () async {
    await store.saveAll([
      _msg(_root, second: 0),
      for (var i = 1; i <= 120; i++) _msg('r$i', minute: i, parentId: _root),
    ]);
    repo.offline = true;

    await notifier().loadFeed(_open, threadRootId: _root, force: true);

    final first = feed(_open, thread: _root);
    expect(first.error, isEmpty);
    expect(first.messages, isNotEmpty);
    expect(first.messages.last.id, 'r120');
    expect(first.hasMore, isTrue);
    final before = first.messages.length;

    await notifier().loadMoreFeed(_open, threadRootId: _root);

    final paged = feed(_open, thread: _root);
    expect(paged.messages.length, greaterThan(before));
    expect(paged.messages.first.id, 'r1');
    expect(paged.loadingMore, isFalse);
  });

  test(
    'a thread opened from disk agrees with the summary under its root',
    () async {
      await store.saveAll([
        _msg('t1', second: 1, parentId: _root),
        _msg('t2', second: 2, parentId: _root),
      ]);
      repo.offline = true;

      await notifier().loadFeed(_open, threadRootId: _root, force: true);

      expect(ids(_open, thread: _root), ['t1', 't2']);
      expect(
        container
            .read(chatProvider)
            .threadRepliesByRoot[_root]
            ?.map((m) => m.id)
            .toList(),
        ['t1', 't2'],
      );
    },
  );

  test('with nothing cached and no network the feed says so', () async {
    repo.offline = true;

    await notifier().loadFeed(_open, force: true);

    expect(feed(_open).messages, isEmpty);
    expect(feed(_open).loading, isFalse);
    expect(feed(_open).error, isNotEmpty);
  });
}
