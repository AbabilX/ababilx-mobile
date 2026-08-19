import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/ws_client.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../chat_utils.dart';
import '../data/chat_repository.dart';
import '../data/local/chat_feed_cache.dart';
import '../data/local/chat_outbox_cache.dart';
import '../data/local/chat_sidebar_cache.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/message_vault.dart';
import 'chat_state.dart';

export 'chat_state.dart';

part 'chat_provider_patch.dart';
part 'chat_provider_feed.dart';
part 'chat_provider_actions.dart';
part 'chat_provider_mutate.dart';
part 'chat_provider_ws.dart';
part 'chat_provider_cache.dart';

class ChatNotifier extends Notifier<ChatState>
    with
        _ChatPatchMixin,
        _ChatFeedMixin,
        _ChatActionsMixin,
        _ChatMutateMixin,
        _ChatWsMixin,
        _ChatCacheMixin {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  WsClient get _ws => ref.read(wsClientProvider);
  bool _realtimeStarted = false;
  bool _bootstrapped = false;
  Future<void>? _bootstrapInFlight;
  StreamSubscription<Map<String, dynamic>>? _wsEventSub;
  StreamSubscription<void>? _wsReconnectSub;
  StreamSubscription<void>? _wsDisconnectSub;

  @override
  ChatRepository get repo => _repo;

  @override
  WsClient get ws => _ws;

  @override
  ChatSidebarCache get sidebarCache => ref.read(chatSidebarCacheProvider);

  @override
  ChatFeedCache get feedCache => ref.read(chatFeedCacheProvider);

  @override
  ChatOutboxCache get outboxCache => ref.read(chatOutboxCacheProvider);

  @override
  bool get realtimeStarted => _realtimeStarted;

  @override
  set realtimeStarted(bool v) => _realtimeStarted = v;

  @override
  StreamSubscription<Map<String, dynamic>>? get wsEventSub => _wsEventSub;

  @override
  set wsEventSub(StreamSubscription<Map<String, dynamic>>? value) =>
      _wsEventSub = value;

  @override
  StreamSubscription<void>? get wsReconnectSub => _wsReconnectSub;

  @override
  set wsReconnectSub(StreamSubscription<void>? value) =>
      _wsReconnectSub = value;

  @override
  StreamSubscription<void>? get wsDisconnectSub => _wsDisconnectSub;

  @override
  set wsDisconnectSub(StreamSubscription<void>? value) =>
      _wsDisconnectSub = value;

  @override
  Future<void> fetchSidebarSilent() => fetchSidebar(silent: true);

  @override
  ChatState build() {
    ref.onDispose(disposeRealtime);
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
    try {
      await ensureCurrentUserId();
    } catch (_) {}
    try {
      await ref.read(messageVaultProvider).restoreTrustedIdentity();
    } catch (_) {}

    // WhatsApp-style: paint cached sidebar first, then refresh network.
    final hadCache = await hydrateSidebarFromCache();
    try {
      await hydrateOutboxMessages();
    } catch (_) {}
    try {
      await fetchSidebar(silent: hadCache);
    } catch (_) {}
    initRealtime();
    _bootstrapped = true;
  }

  /// Runs [bootstrap] at most once per session, whoever asks first. A chat
  /// opened straight from a push notification has no MessagesScreen above it,
  /// so it must be able to start the same load ChatStoreSync normally does —
  /// otherwise it renders before the sidebar and vault exist.
  Future<void> ensureReady() {
    if (_bootstrapped) return Future<void>.value();
    return _bootstrapInFlight ??= bootstrap().whenComplete(() {
      _bootstrapInFlight = null;
    });
  }

  /// E2EE envelopes are authenticated with the backend user UUID. Never
  /// attempt key unwrap/decryption until that UUID has been resolved.
  Future<String> ensureCurrentUserId() async {
    final existing = state.currentUserId.trim();
    if (existing.isNotEmpty) return existing;

    var profile = ref.read(profileProvider).valueOrNull;
    if (profile == null || profile.id.trim().isEmpty) {
      final cached = await ref.read(profileRepositoryProvider).getCachedMe();
      if (cached != null && cached.id.trim().isNotEmpty) {
        profile = cached;
      } else {
        try {
          await ref.read(profileProvider.notifier).refresh();
          profile = ref.read(profileProvider).valueOrNull;
        } catch (_) {}
      }
    }
    final userId = profile?.id.trim() ?? '';
    if (userId.isEmpty) {
      final cached = await ref.read(profileRepositoryProvider).getCachedMe();
      if (cached != null && cached.id.trim().isNotEmpty) {
        state = state.copyWith(currentUserId: cached.id.trim());
        return cached.id.trim();
      }
      throw StateError('Authenticated user is not ready');
    }
    state = state.copyWith(currentUserId: userId);
    return userId;
  }

  void resetTeamChatState({bool clearCurrentUser = false}) {
    _bootstrapped = false;
    state = ChatState(
      currentUserId: clearCurrentUser ? '' : state.currentUserId,
    );
  }

  Future<void> fetchSidebar({bool silent = false}) async {
    if (!silent) state = state.copyWith(sidebarLoading: true);
    try {
      final data = await _repo.listConversations();
      final dms = sortDms(await _decryptDmPreviews(data.dms));
      final channels = sortChannels(data.channels);
      final active = state.activeConversationId;
      final known =
          active != null &&
          (dms.any((d) => d.id == active) ||
              channels.any((c) => c.id == active));
      state = state.copyWith(
        dms: dms,
        channels: channels,
        activeConversationId: known ? active : null,
        clearThreadRoot: !known,
        sidebarLoading: false,
      );
      await persistSidebar(ChatSidebar(channels: channels, dms: dms));
    } catch (_) {
      // Keep cached rows on network failure — never clear local state
      state = state.copyWith(sidebarLoading: false);
    }
  }

  void setActiveConversation(String? id) {
    if (id != null && !isValidConversationId(id)) return;
    state = state.copyWith(
      activeConversationId: id,
      clearThreadRoot: true,
      clearReplyTo: true,
    );
  }

  void setThreadRootId(String? id) {
    state = state.copyWith(threadRootId: id, clearThreadRoot: id == null);
  }

  void setReplyToMessage(ChatMessage? message) {
    state = state.copyWith(
      replyToMessage: message,
      clearReplyTo: message == null,
    );
  }

  void clearUnread(String conversationId) {
    state = state.copyWith(
      dms: patchList(state.dms, conversationId, unreadCount: 0),
      channels: patchList(state.channels, conversationId, unreadCount: 0),
    );
  }

  Future<List<ChatConversation>> _decryptDmPreviews(
    List<ChatConversation> dms,
  ) async {
    final userId = await ensureCurrentUserId();
    return Future.wait(
      dms.map((dm) async {
        if (dm.lastMessageEncryptionVersion != 1 ||
            dm.lastMessageEncryptedBody == null ||
            dm.lastMessageUserId == null) {
          return dm;
        }
        final preview = await ref
            .read(messageVaultProvider)
            .decryptMessage(
              ChatMessage(
                id: 'sidebar-${dm.id}',
                conversationId: dm.id,
                userId: dm.lastMessageUserId!,
                body: dm.lastMessageBody ?? '',
                createdAt: dm.lastMessageAt ?? '',
                encryptedBody: dm.lastMessageEncryptedBody,
                encryptionNonce: dm.lastMessageEncryptionNonce,
                encryptionVersion: dm.lastMessageEncryptionVersion,
                encryptionKeyVersion: dm.lastMessageEncryptionKeyVersion,
              ),
              userId,
            );
        return dm.copyWith(lastMessageBody: preview.body);
      }),
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

final totalUnreadProvider = Provider<int>((ref) {
  final chat = ref.watch(chatProvider);
  return totalUnread(chat.dms, chat.channels);
});

final activeConversationProvider = Provider<ChatConversation?>((ref) {
  final chat = ref.watch(chatProvider);
  return chat.conversationById(chat.activeConversationId);
});
