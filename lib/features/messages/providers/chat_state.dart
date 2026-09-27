import '../chat_utils.dart';
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
    this.error = '',
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingMore;
  final String nextCursor;
  final bool hasMore;
  final int fetchedAt;

  /// Set when a load failed. Without it a failed fetch is indistinguishable
  /// from an empty conversation and the screen stays silently blank.
  final String error;

  ChatFeed copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? loadingMore,
    String? nextCursor,
    bool? hasMore,
    int? fetchedAt,
    String? error,
  }) => ChatFeed(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    error: error ?? this.error,
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
    this.replyToMessage,
  });

  final List<ChatConversation> dms;
  final List<ChatConversation> channels;
  final bool sidebarLoading;
  final String currentUserId;
  final String? activeConversationId;
  final String? threadRootId;
  final ChatMessage? replyToMessage;
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
    bool clearActiveConversation = false,
    String? threadRootId,
    bool clearThreadRoot = false,
    ChatMessage? replyToMessage,
    bool clearReplyTo = false,
    Map<String, ChatFeed>? feeds,
    Map<String, List<ChatMessage>>? threadRepliesByRoot,
    bool? sending,
    String? searchQuery,
    List<ChatMessage>? searchResults,
    bool? searchLoading,
    bool? wsConnected,
  }) => ChatState(
    dms: dms ?? this.dms,
    channels: channels ?? this.channels,
    sidebarLoading: sidebarLoading ?? this.sidebarLoading,
    currentUserId: currentUserId ?? this.currentUserId,
    // `null` alone keeps the old id (every field here does); leaving a chat
    // needs the flag, or the chat stays "active" and its next message is
    // acknowledged as read to the sender.
    activeConversationId: clearActiveConversation
        ? null
        : (activeConversationId ?? this.activeConversationId),
    threadRootId: clearThreadRoot ? null : (threadRootId ?? this.threadRootId),
    replyToMessage: clearReplyTo
        ? null
        : (replyToMessage ?? this.replyToMessage),
    feeds: feeds ?? this.feeds,
    threadRepliesByRoot: threadRepliesByRoot ?? this.threadRepliesByRoot,
    sending: sending ?? this.sending,
    searchQuery: searchQuery ?? this.searchQuery,
    searchResults: searchResults ?? this.searchResults,
    searchLoading: searchLoading ?? this.searchLoading,
    wsConnected: wsConnected ?? this.wsConnected,
  );
}
