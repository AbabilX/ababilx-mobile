import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/ws_client.dart';
import '../../profile/providers/profile_provider.dart';
import '../chat_utils.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_models.dart';

const feedStaleMs = 45000;

class ChatFeed {
  const ChatFeed({
    this.messages = const [],
    this.loading = false,
    this.loadingMore = false,
    this.nextCursor = '',
    this.hasMore = false,
    this.fetchedAt = 0,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingMore;
  final String nextCursor;
  final bool hasMore;
  final int fetchedAt;

  ChatFeed copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? loadingMore,
    String? nextCursor,
    bool? hasMore,
    int? fetchedAt,
  }) =>
      ChatFeed(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
}

class ChatState {
  const ChatState({
    this.dms = const [],
    this.channels = const [],
    this.sidebarLoading = false,
    this.currentUserId = '',
    this.activeConversationId,
    this.threadRootId,
    this.feeds = const {},
    this.threadRepliesByRoot = const {},
    this.sending = false,
    this.searchQuery = '',
    this.searchResults = const [],
    this.searchLoading = false,
    this.wsConnected = false,
  });

  final List<ChatConversation> dms;
  final List<ChatConversation> channels;
  final bool sidebarLoading;
  final String currentUserId;
  final String? activeConversationId;
  final String? threadRootId;
  final Map<String, ChatFeed> feeds;
  final Map<String, List<ChatMessage>> threadRepliesByRoot;
  final bool sending;
  final String searchQuery;
  final List<ChatMessage> searchResults;
  final bool searchLoading;
  final bool wsConnected;

  ChatConversation? conversationById(String? id) {
    if (id == null) return null;
    for (final c in dms) {
      if (c.id == id) return c;
    }
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  ChatFeed feedFor(String conversationId, {String? threadRootId}) {
    return feeds[feedKey(conversationId, threadRootId: threadRootId)] ??
        const ChatFeed();
  }

  ChatState copyWith({
    List<ChatConversation>? dms,
    List<ChatConversation>? channels,
    bool? sidebarLoading,
    String? currentUserId,
    String? activeConversationId,
    String? threadRootId,
    bool clearThreadRoot = false,
    Map<String, ChatFeed>? feeds,
    Map<String, List<ChatMessage>>? threadRepliesByRoot,
    bool? sending,
    String? searchQuery,
    List<ChatMessage>? searchResults,
    bool? searchLoading,
    bool? wsConnected,
  }) =>
      ChatState(
        dms: dms ?? this.dms,
        channels: channels ?? this.channels,
        sidebarLoading: sidebarLoading ?? this.sidebarLoading,
        currentUserId: currentUserId ?? this.currentUserId,
        activeConversationId: activeConversationId ?? this.activeConversationId,
        threadRootId:
            clearThreadRoot ? null : (threadRootId ?? this.threadRootId),
        feeds: feeds ?? this.feeds,
        threadRepliesByRoot:
            threadRepliesByRoot ?? this.threadRepliesByRoot,
        sending: sending ?? this.sending,
        searchQuery: searchQuery ?? this.searchQuery,
        searchResults: searchResults ?? this.searchResults,
        searchLoading: searchLoading ?? this.searchLoading,
        wsConnected: wsConnected ?? this.wsConnected,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  WsClient get _ws => ref.read(wsClientProvider);
  bool _realtimeStarted = false;

  @override
  ChatState build() {
    ref.listen(profileProvider, (prev, next) {
      final id = next.valueOrNull?.id;
      if (id != null && id.isNotEmpty) {
        state = state.copyWith(currentUserId: id);
      }
    });
    final profile = ref.read(profileProvider).valueOrNull;
    return ChatState(currentUserId: profile?.id ?? '');
  }

  Future<void> bootstrap() async {
    final profile = ref.read(profileProvider);
    if (profile.valueOrNull == null) {
      await ref.read(profileProvider.notifier).refresh();
    }
    final userId = ref.read(profileProvider).valueOrNull?.id;
    if (userId != null) {
      state = state.copyWith(currentUserId: userId);
    }
    await fetchSidebar();
    initRealtime();
  }

  void resetTeamChatState() {
    state = ChatState(currentUserId: state.currentUserId);
  }

  Future<void> fetchSidebar({bool silent = false}) async {
    if (!silent) state = state.copyWith(sidebarLoading: true);
    try {
      final data = await _repo.listConversations();
      final dms = sortDms(data.dms);
      final channels = sortChannels(data.channels);
      final active = state.activeConversationId;
      final known = active != null &&
          (dms.any((d) => d.id == active) ||
              channels.any((c) => c.id == active));
      state = state.copyWith(
        dms: dms,
        channels: channels,
        activeConversationId: known ? active : null,
        clearThreadRoot: !known,
        sidebarLoading: false,
      );
    } catch (_) {
      resetTeamChatState();
      state = state.copyWith(sidebarLoading: false);
    }
  }

  void setActiveConversation(String? id) {
    if (id != null && !isValidConversationId(id)) return;
    state = state.copyWith(
      activeConversationId: id,
      clearThreadRoot: true,
    );
  }

  void setThreadRootId(String? id) {
    state = state.copyWith(threadRootId: id, clearThreadRoot: id == null);
  }

  void clearUnread(String conversationId) {
    state = state.copyWith(
      dms: _patchList(state.dms, conversationId, unreadCount: 0),
      channels: _patchList(state.channels, conversationId, unreadCount: 0),
    );
  }

  List<ChatConversation> _patchList(
    List<ChatConversation> list,
    String id, {
    int? unreadCount,
    bool bumpUnread = false,
    String? lastMessageAt,
    String? lastMessageBody,
    String? lastMessageUserId,
    String? lastMessageAttachmentType,
    String? lastMessageAttachmentName,
    bool? muted,
    String? name,
  }) {
    final next = list.map((c) {
      if (c.id != id) return c;
      var unread = c.unreadCount;
      if (unreadCount != null) unread = unreadCount;
      if (bumpUnread) unread = c.unreadCount + 1;
      return c.copyWith(
        unreadCount: unread,
        lastMessageAt: lastMessageAt ?? c.lastMessageAt,
        lastMessageBody: lastMessageBody ?? c.lastMessageBody,
        lastMessageUserId: lastMessageUserId ?? c.lastMessageUserId,
        lastMessageAttachmentType:
            lastMessageAttachmentType ?? c.lastMessageAttachmentType,
        lastMessageAttachmentName:
            lastMessageAttachmentName ?? c.lastMessageAttachmentName,
        muted: muted ?? c.muted,
        name: name,
      );
    }).toList();
    return list.any((c) => c.isDm)
        ? sortDms(next)
        : sortChannels(next);
  }

  void applyIncomingMessage(
    String conversationId,
    ChatMessage msg, {
    required bool bumpUnread,
  }) {
    final firstAtt = msg.attachments.isNotEmpty ? msg.attachments.first : null;
    final patch = {
      'lastMessageAt': msg.createdAt,
      'lastMessageBody': msg.body,
      'lastMessageUserId': msg.userId,
      'lastMessageAttachmentType': firstAtt?.contentType,
      'lastMessageAttachmentName': firstAtt?.fileName,
      'bumpUnread': bumpUnread,
    };
    state = state.copyWith(
      dms: _patchList(
        state.dms,
        conversationId,
        lastMessageAt: patch['lastMessageAt'] as String?,
        lastMessageBody: patch['lastMessageBody'] as String?,
        lastMessageUserId: patch['lastMessageUserId'] as String?,
        lastMessageAttachmentType:
            patch['lastMessageAttachmentType'] as String?,
        lastMessageAttachmentName:
            patch['lastMessageAttachmentName'] as String?,
        bumpUnread: bumpUnread,
      ),
      channels: _patchList(
        state.channels,
        conversationId,
        lastMessageAt: patch['lastMessageAt'] as String?,
        lastMessageBody: patch['lastMessageBody'] as String?,
        lastMessageUserId: patch['lastMessageUserId'] as String?,
        lastMessageAttachmentType:
            patch['lastMessageAttachmentType'] as String?,
        lastMessageAttachmentName:
            patch['lastMessageAttachmentName'] as String?,
        bumpUnread: bumpUnread,
      ),
    );
  }

  void upsertDm(ChatConversation dm) {
    final exists = state.dms.any((d) => d.id == dm.id);
    final merged = exists
        ? state.dms
            .map((d) => d.id == dm.id
                ? ChatConversation(
                    id: dm.id,
                    teamId: dm.teamId,
                    type: dm.type,
                    name: dm.name ?? d.name,
                    slug: dm.slug ?? d.slug,
                    isPrivate: dm.isPrivate,
                    createdBy: dm.createdBy ?? d.createdBy,
                    createdAt: dm.createdAt,
                    unreadCount: dm.unreadCount,
                    lastMessageAt: dm.lastMessageAt ?? d.lastMessageAt,
                    lastMessageBody: dm.lastMessageBody ?? d.lastMessageBody,
                    peerUserId: dm.peerUserId ?? d.peerUserId,
                    peerUserName: dm.peerUserName ?? d.peerUserName,
                    peerUserAvatar: dm.peerUserAvatar ?? d.peerUserAvatar,
                  )
                : d)
            .toList()
        : [dm, ...state.dms];
    state = state.copyWith(dms: sortDms(merged));
  }

  void upsertChannel(ChatConversation channel) {
    final exists = state.channels.any((c) => c.id == channel.id);
    final merged = exists
        ? state.channels
            .map((c) => c.id == channel.id
                ? ChatConversation(
                    id: channel.id,
                    teamId: channel.teamId,
                    type: channel.type,
                    name: channel.name ?? c.name,
                    slug: channel.slug ?? c.slug,
                    isPrivate: channel.isPrivate,
                    createdAt: channel.createdAt,
                    unreadCount: channel.unreadCount,
                  )
                : c)
            .toList()
        : [channel, ...state.channels];
    state = state.copyWith(channels: sortChannels(merged));
  }

  Future<void> loadFeed(
    String conversationId, {
    String? threadRootId,
    bool force = false,
  }) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final existing = state.feeds[key] ?? const ChatFeed();
    final hasMessages = existing.messages.isNotEmpty;
    final stale =
        existing.fetchedAt == 0 ||
        DateTime.now().millisecondsSinceEpoch - existing.fetchedAt >
            feedStaleMs;

    if (!force && hasMessages && !stale) return;

    if (!hasMessages) {
      _setFeed(key, existing.copyWith(loading: true));
    }

    try {
      final page = await _repo.listMessages(
        conversationId,
        limit: threadRootId != null ? 100 : 50,
        thread: threadRootId,
      );
      final sorted = threadRootId != null
          ? page.messages
          : page.messages.reversed.toList();
      _setFeed(
        key,
        ChatFeed(
          messages: sorted,
          loading: false,
          loadingMore: false,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      _setFeed(key, (state.feeds[key] ?? const ChatFeed()).copyWith(loading: false));
    }
  }

  Future<void> loadMoreFeed(String conversationId, {String? threadRootId}) async {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key] ?? const ChatFeed();
    if (!feed.hasMore || feed.nextCursor.isEmpty || feed.loadingMore) return;

    _setFeed(key, feed.copyWith(loadingMore: true));

    try {
      final page = await _repo.listMessages(
        conversationId,
        cursor: feed.nextCursor,
        limit: threadRootId != null ? 100 : 50,
        thread: threadRootId,
      );
      final sorted = threadRootId != null
          ? page.messages
          : page.messages.reversed.toList();
      _setFeed(
        key,
        feed.copyWith(
          messages: [...sorted, ...feed.messages],
          loadingMore: false,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      _setFeed(key, feed.copyWith(loadingMore: false));
    }
  }

  void _setFeed(String key, ChatFeed feed) {
    state = state.copyWith(feeds: {...state.feeds, key: feed});
  }

  void appendFeedMessage(
    String conversationId,
    ChatMessage msg, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key] ?? const ChatFeed();
    if (feed.messages.any((m) => m.id == msg.id)) return;
    _setFeed(
      key,
      feed.copyWith(
        messages: [...feed.messages, msg],
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void updateFeedMessage(
    String conversationId,
    ChatMessage msg, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    _setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.map((m) => m.id == msg.id ? msg : m).toList(),
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void removeFeedMessage(
    String conversationId,
    String messageId, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    _setFeed(
      key,
      feed.copyWith(
        messages: feed.messages.where((m) => m.id != messageId).toList(),
      ),
    );
  }

  void updateFeedReactions(
    String conversationId,
    String messageId,
    List<ChatReactionGroup> reactions, {
    String? threadRootId,
  }) {
    final key = feedKey(conversationId, threadRootId: threadRootId);
    final feed = state.feeds[key];
    if (feed == null) return;
    _setFeed(
      key,
      feed.copyWith(
        messages: feed.messages
            .map((m) => m.id == messageId ? m.copyWith(reactions: reactions) : m)
            .toList(),
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void incrementThreadCount(String conversationId, String rootId) {
    final key = feedKey(conversationId);
    final feed = state.feeds[key];
    if (feed == null) return;
    _setFeed(
      key,
      feed.copyWith(
        messages: feed.messages
            .map((m) => m.id == rootId
                ? m.copyWith(threadCount: m.threadCount + 1)
                : m)
            .toList(),
      ),
    );
  }

  void appendThreadReply(String rootId, ChatMessage msg) {
    final list = state.threadRepliesByRoot[rootId] ?? [];
    if (list.any((m) => m.id == msg.id)) return;
    state = state.copyWith(
      threadRepliesByRoot: {
        ...state.threadRepliesByRoot,
        rootId: [...list, msg],
      },
    );
  }

  void patchThreadReply(String rootId, ChatMessage msg) {
    final list = state.threadRepliesByRoot[rootId];
    if (list == null) return;
    state = state.copyWith(
      threadRepliesByRoot: {
        ...state.threadRepliesByRoot,
        rootId: list.map((m) => m.id == msg.id ? msg : m).toList(),
      },
    );
  }

  void markThreadReplyDeleted(String rootId, String messageId) {
    final list = state.threadRepliesByRoot[rootId];
    if (list == null) return;
    state = state.copyWith(
      threadRepliesByRoot: {
        ...state.threadRepliesByRoot,
        rootId: list
            .map((m) => m.id == messageId
                ? m.copyWith(
                    deletedAt: DateTime.now().toUtc().toIso8601String(),
                    body: '',
                  )
                : m)
            .toList(),
      },
    );
  }

  Future<ChatMessage?> sendMessage({
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
  }) async {
    final convId = state.activeConversationId;
    if (convId == null) return null;
    state = state.copyWith(sending: true);
    try {
      final msg = await _repo.sendMessage(
        convId,
        body: body,
        parentId: parentId,
        attachments: attachments,
        mentionedUserIds: mentionedUserIds,
      );
      final threadRootId = state.threadRootId;
      if (parentId != null) {
        if (threadRootId != null && parentId == threadRootId) {
          appendFeedMessage(convId, msg, threadRootId: threadRootId);
          appendThreadReply(threadRootId, msg);
        }
      } else {
        appendFeedMessage(convId, msg);
      }
      applyIncomingMessage(convId, msg, bumpUnread: false);
      return msg;
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    clearUnread(conversationId);
    try {
      await _repo.markRead(conversationId);
    } catch (_) {}
  }

  Future<ChatConversation> createChannel({
    required String name,
    bool isPrivate = false,
  }) async {
    final channel = await _repo.createChannel(
      name: name,
      slug: slugifyChannel(name),
      isPrivate: isPrivate,
    );
    upsertChannel(channel);
    return channel;
  }

  Future<ChatConversation> startDm(String userId) async {
    final dm = await _repo.startDm(userId);
    upsertDm(dm);
    return dm;
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final reactions = await _repo.toggleReaction(messageId, emoji);
    final convId = state.activeConversationId;
    if (convId == null) return;
    updateFeedReactions(convId, messageId, reactions);
    updateFeedReactions(
      convId,
      messageId,
      reactions,
      threadRootId: state.threadRootId,
    );
  }

  Future<void> editMessage(String messageId, String body) async {
    final msg = await _repo.patchMessage(messageId, body);
    final convId = state.activeConversationId;
    if (convId == null) return;
    updateFeedMessage(convId, msg);
    updateFeedMessage(convId, msg, threadRootId: state.threadRootId);
    if (msg.parentId != null) patchThreadReply(msg.parentId!, msg);
  }

  Future<void> deleteMessage(String messageId) async {
    await _repo.deleteMessage(messageId);
    final convId = state.activeConversationId;
    if (convId == null) return;
    removeFeedMessage(convId, messageId);
    removeFeedMessage(convId, messageId, threadRootId: state.threadRootId);
    for (final rootId in state.threadRepliesByRoot.keys) {
      markThreadReplyDeleted(rootId, messageId);
    }
  }

  Future<int> forwardMessage({
    required String messageId,
    List<String>? conversationIds,
    List<String>? userIds,
    String? caption,
  }) =>
      _repo.forwardMessage(
        messageId: messageId,
        conversationIds: conversationIds,
        userIds: userIds,
        caption: caption,
      );

  Future<void> searchMessages(String q) async {
    state = state.copyWith(searchQuery: q, searchLoading: true);
    try {
      final results = await _repo.searchMessages(q);
      state = state.copyWith(searchResults: results, searchLoading: false);
    } catch (_) {
      state = state.copyWith(searchResults: [], searchLoading: false);
    }
  }

  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) =>
      _repo.presignAttachment(
        conversationId,
        contentType: contentType,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );

  Future<void> uploadAttachmentBytes(
    ChatPresignResult presign,
    List<int> bytes,
    String contentType,
  ) async {
    final dio = Dio();
    await dio.put(
      presign.uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
    );
  }

  Future<void> discardUpload(String conversationId, String fileUrl) =>
      _repo.discardUpload(conversationId, fileUrl);

  Future<ChatConversation> renameChannel(String id, String name) async {
    final updated = await _repo.patchChannel(id, name: name);
    upsertChannel(updated);
    return updated;
  }

  Future<void> muteConversation(String id, bool muted) async {
    await _repo.muteConversation(id, muted);
    state = state.copyWith(
      dms: _patchList(state.dms, id, muted: muted),
      channels: _patchList(state.channels, id, muted: muted),
    );
  }

  Future<List<ChatMember>> listChannelMembers(String channelId) =>
      _repo.listChannelMembers(channelId);

  Future<void> addChannelMember(String channelId, String userId) =>
      _repo.addChannelMember(channelId, userId);

  Future<void> leaveChannel(String channelId) async {
    await _repo.leaveChannel(channelId);
    await fetchSidebar(silent: true);
  }

  Future<void> deleteChannel(String channelId) async {
    await _repo.deleteChannel(channelId);
    await fetchSidebar(silent: true);
  }

  void handleWsEvent(Map<String, dynamic> ev) {
    final type = ev['type'] as String? ?? '';
    if (type == 'chat.conversation.updated') {
      unawaited(fetchSidebar(silent: true));
      return;
    }

    if (type == 'chat.message.created') {
      final convId = ev['conversation_id'] as String? ?? '';
      final msgJson = ev['message'] as Map<String, dynamic>?;
      if (msgJson == null) return;
      final msg = ChatMessage.fromJson(msgJson);
      final isActive = convId == state.activeConversationId;
      final known = state.dms.any((d) => d.id == convId) ||
          state.channels.any((c) => c.id == convId);
      if (!known) unawaited(fetchSidebar(silent: true));

      if (isActive) {
        applyIncomingMessage(convId, msg, bumpUnread: false);
        if (msg.parentId != null) {
          final threadRootId = state.threadRootId;
          if (threadRootId != null && msg.parentId == threadRootId) {
            appendFeedMessage(convId, msg, threadRootId: threadRootId);
            appendThreadReply(threadRootId, msg);
          } else if (msg.parentId != null) {
            incrementThreadCount(convId, msg.parentId!);
            appendThreadReply(msg.parentId!, msg);
          }
        } else {
          appendFeedMessage(convId, msg);
        }
      } else {
        applyIncomingMessage(
          convId,
          msg,
          bumpUnread: msg.userId != state.currentUserId,
        );
      }
      return;
    }

    final convId = ev['conversation_id'] as String? ?? '';
    if (convId != state.activeConversationId) return;

    if (type == 'chat.message.updated') {
      final msgJson = ev['message'] as Map<String, dynamic>?;
      if (msgJson == null) return;
      final msg = ChatMessage.fromJson(msgJson);
      updateFeedMessage(convId, msg);
      updateFeedMessage(convId, msg, threadRootId: state.threadRootId);
      if (msg.parentId != null) patchThreadReply(msg.parentId!, msg);
    }

    if (type == 'chat.message.deleted') {
      final id = ev['id'] as String? ?? '';
      removeFeedMessage(convId, id);
      removeFeedMessage(convId, id, threadRootId: state.threadRootId);
      for (final rootId in state.threadRepliesByRoot.keys) {
        markThreadReplyDeleted(rootId, id);
      }
    }

    if (type == 'chat.reaction.updated') {
      final id = ev['id'] as String? ?? '';
      final reactions = (ev['reactions'] as List<dynamic>? ?? [])
          .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
          .toList();
      updateFeedReactions(convId, id, reactions);
      updateFeedReactions(
        convId,
        id,
        reactions,
        threadRootId: state.threadRootId,
      );
    }
  }

  void initRealtime() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;
    _ws.onEvent = (ev) {
      final type = ev['type'] as String? ?? '';
      if (type.startsWith('chat.')) {
        handleWsEvent(ev);
      }
    };
    _ws.onReconnect = () {
      state = state.copyWith(wsConnected: true);
      unawaited(fetchSidebar(silent: true));
      final active = state.activeConversationId;
      if (active != null) {
        unawaited(loadFeed(active, force: true));
        final thread = state.threadRootId;
        if (thread != null) {
          unawaited(loadFeed(active, threadRootId: thread, force: true));
        }
      }
    };
    unawaited(_ws.connect());
  }

  void disposeRealtime() {
    _realtimeStarted = false;
    _ws.disconnect();
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

final totalUnreadProvider = Provider<int>((ref) {
  final chat = ref.watch(chatProvider);
  return totalUnread(chat.dms, chat.channels);
});

final activeConversationProvider = Provider<ChatConversation?>((ref) {
  final chat = ref.watch(chatProvider);
  return chat.conversationById(chat.activeConversationId);
});
