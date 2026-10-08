import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_row.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/chat_sidebar_cache.dart'
    show chatLocalDbProvider;
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const conv = '11111111-1111-4111-8111-111111111111';

/// When message 0 was written. Two days ago by default, so the history is
/// recent; a test moves it to make the history old.
DateTime historyStart = recentHistoryStart();

DateTime recentHistoryStart() =>
    DateTime.now().toUtc().subtract(const Duration(days: 2));

/// Message number [n], written one minute after number n-1. The zero-padded
/// id sorts the way the time does.
ChatMessage msg(
  int n, {
  int threadCount = 0,
  int revision = 0,
  bool privateChat = false,
  List<ChatReactionGroup> reactions = const [],
  ChatDeliverySummary? delivery,
}) => ChatMessage(
  id: 'm${n.toString().padLeft(4, '0')}',
  conversationId: conv,
  userId: 'peer',
  body: 'body $n',
  threadCount: threadCount,
  revision: revision,
  privateChat: privateChat,
  reactions: reactions,
  delivery: delivery,
  createdAt: historyStart.add(Duration(minutes: n)).toIso8601String(),
);

String idOf(int n) => 'm${n.toString().padLeft(4, '0')}';

/// A server that pages the way the real one does: by last activity, newest
/// first, a message id as the cursor, and an EMPTY page for an id it does
/// not hold.
class FakeServer extends ChatRepository {
  FakeServer() : super(ApiClient(const SecureStorage(FlutterSecureStorage())));

  final rows = <ChatMessage>[];

  /// Messages listed where their newest thread reply is, not where they
  /// were written.
  final activityMs = <String, int>{};
  bool offline = false;

  /// The cursor of every list request; null is a newest-page request.
  final cursors = <String?>[];

  int get olderRequests => cursors.where((c) => c != null).length;

  int _activity(ChatMessage m) => activityMs[m.id] ?? messageTimeMs(m);

  @override
  Future<ChatMessagesPage> listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
    String? thread,
  }) async {
    cursors.add(cursor);
    if (offline) throw StateError('network unreachable');
    final size = limit ?? 50;
    final ordered = [...rows]
      ..sort((a, b) {
        final byActivity = _activity(b).compareTo(_activity(a));
        return byActivity != 0 ? byActivity : b.id.compareTo(a.id);
      });
    var from = 0;
    if (cursor != null && cursor.isNotEmpty) {
      final at = ordered.indexWhere((m) => m.id == cursor);
      if (at < 0) {
        return const ChatMessagesPage(
          messages: [],
          nextCursor: '',
          hasMore: false,
        );
      }
      from = at + 1;
    }
    final slice = ordered.skip(from).take(size + 1).toList();
    final hasMore = slice.length > size;
    final page = hasMore ? slice.sublist(0, size) : slice;
    return ChatMessagesPage(
      messages: page,
      nextCursor: hasMore ? page.last.id : '',
      hasMore: hasMore,
    );
  }

  @override
  Future<void> acknowledgeMessages(String status, List<String> ids) async {}

  @override
  Future<void> markRead(String conversationId) async {}
}

class _Notifier extends ChatNotifier {
  _Notifier(this._server);

  final FakeServer _server;

  @override
  ChatRepository get repo => _server;

  @override
  Future<String> ensureCurrentUserId() async => 'me';

  @override
  Future<void> fetchSidebarSilent() async {}

  @override
  ChatState build() {
    super.build();
    return const ChatState(
      currentUserId: 'me',
      dms: [ChatConversation(id: conv, teamId: '', type: 'dm', createdAt: '')],
    );
  }
}

/// One launch of the app over [db]: a fresh notifier and a fresh span store,
/// reading whatever the last launch left on disk and in preferences.
ProviderContainer launch(ChatLocalDb db, FakeServer server) =>
    ProviderContainer(
      overrides: [
        chatLocalDbProvider.overrideWithValue(db),
        chatMessageStoreProvider.overrideWithValue(ChatMessageStore(db)),
        chatProvider.overrideWith(() => _Notifier(server)),
      ],
    );

extension Session on ProviderContainer {
  ChatNotifier get chat => read(chatProvider.notifier);
  ChatFeed get feed => read(chatProvider).feedFor(conv);
  List<String> get shown => feed.messages.map((m) => m.id).toList();

  Future<void> open() async {
    await chat.hydrateFeedFromCache(conv);
    await chat.loadFeed(conv, force: true);
  }

  /// Scrolls back until the history ends or [pages] loads have run.
  Future<void> scrollBack([int pages = 1]) async {
    for (var i = 0; i < pages && feed.hasMore; i++) {
      await chat.loadMoreFeed(conv);
    }
  }
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
