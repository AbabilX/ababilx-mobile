import 'dart:async';
import 'dart:io';
import '../data/local/chat_deletion_sync.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../../../core/network/ws_client.dart';
import '../../attachments/crypto/sealed_upload.dart';
import '../../attachments/crypto/sealed_upload_policy.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../notifications/chat/chat_notification_presenter.dart';
import '../../dm-settings/receipts/receipts_hidden_provider.dart';
import '../../privacy-mode/peer_privacy_provider.dart';
import '../../privacy-mode/privacy_media.dart';
import '../../private-chat/private_chat_api.dart';
import '../../private-chat/private_chat_preview.dart';
import '../../private-chat/private_chat_state.dart';
import '../../private-chat/private_custody_media.dart';
import '../../private-chat/private_op.dart';
import '../../notifications/providers/fcm_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../chat-list/chat_list_avatars.dart';
import '../chat-mute/mute_choice.dart';
import '../chat_thread_prefetch.dart';
import '../chat_utils.dart';
import '../history-restore/history_restore_count.dart';
import '../history-restore/history_restore_flag.dart';
import '../history-restore/history_restore_job.dart';
import '../history-restore/history_restore_state.dart';
import '../data/chat_client_message_id.dart';
import '../data/chat_message_merge.dart';
import '../data/chat_repository.dart';
import '../data/send_tracker.dart';
import '../archive/archive_provider.dart';
import '../data/local/chat_message_row.dart';
import '../data/local/chat_message_store.dart';
import '../data/local/conversation_wipe.dart';
import '../data/local/feed_span_store.dart';
import '../data/local/feed_spans.dart';
import '../data/local/chat_outbox_cache.dart';
import '../data/local/local_outbox_cipher.dart';
import '../data/local/composer_draft_store.dart';
import '../data/local/chat_sidebar_cache.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/dm_key_rotation.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/sidebar_preview.dart';
import '../group-member-permissions/group_member_tags_provider.dart';
import '../group-pins/group_pins_provider.dart';
import '../send-later/scheduled_provider.dart';
import '../send-later/scheduled_reseal.dart';
import '../message_e2ee/vault_placeholder.dart';
import 'chat_older_trace.dart';
import 'chat_open_trace.dart';
import 'chat_read_marks.dart';
import 'chat_state.dart';
import 'older_paging_rules.dart';
import 'received_message_buffer.dart';
import '../task/task_card_data.dart';
import '../../chat-lock/chat_lock_filter.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';

export 'chat_open_trace.dart' show ChatOpenTrace;
export 'chat_state.dart';

part 'chat_provider_patch.dart';
part 'chat_provider_feed.dart';
part 'chat_provider_feed_edit.dart';
part 'chat_provider_actions.dart';
part 'chat_provider_mutate.dart';
part 'chat_provider_webhooks.dart';
part 'chat_provider_requests.dart';
part 'chat_provider_ws.dart';
part 'chat_provider_cache.dart';
part 'chat_provider_older_disk.dart';
part 'chat_provider_older_top.dart';
part 'chat_provider_older_server.dart';
part 'chat_provider_older_refresh.dart';
part 'chat_provider_older_edge.dart';
part 'chat_provider_older_end.dart';
part 'chat_provider_older.dart';
part 'chat_provider_outbox.dart';
part 'chat_provider_thread_prefetch.dart';
part 'chat_provider_history_restore.dart';
part 'chat_provider_resync.dart';
part 'chat_provider_preview.dart';
part 'chat_provider_local_preview.dart';
part 'chat_provider_private.dart';
part 'chat_provider_private_ops.dart';

class ChatNotifier extends Notifier<ChatState>
    with
        _ChatPatchMixin,
        _ChatFeedMixin,
        _ChatFeedEditMixin,
        _ChatActionsMixin,
        _ChatMutateMixin,
        _ChatWebhooksMixin,
        _ChatRequestsMixin,
        _ChatWsMixin,
        _ChatCacheMixin,
        _ChatOlderDiskMixin,
        _ChatOlderTopMixin,
        _ChatOlderServerMixin,
        _ChatOlderRefreshMixin,
        _ChatOlderEdgeMixin,
        _ChatOlderEndMixin,
        _ChatOlderMixin,
        _ChatOutboxMixin,
        _ChatThreadPrefetchMixin,
        _ChatHistoryRestoreMixin,
        _ChatResyncMixin,
        _ChatPreviewMixin,
        _ChatLocalPreviewMixin,
        _ChatPrivateMixin,
        _ChatPrivateOpsMixin {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  WsClient get _ws => ref.read(wsClientProvider);
  bool _realtimeStarted = false;
  final _readMarks = ChatReadMarks();
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
  ChatMessageStore get messageStore => ref.read(chatMessageStoreProvider);

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

  /// True once Riverpod has torn this notifier down. Every write that lands
  /// after an `await` has to check it: a conversation can be closed (or the
  /// user signed out) while a feed request is still in flight, and writing
  /// `state` then throws "Cannot use a Notifier after it has been disposed".
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  ChatState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      disposeRealtime();
    });
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
    // WhatsApp-style: paint cached sidebar + outbox first — nothing in this
    // block may touch the network (see hydrateSidebarFromCache / localUserId),
    // so a cold open offline shows the last known chat list instantly
    // instead of waiting on any request to fail or time out.
    await messageStore.deletions.load(await localUserId());
    final hadCache = await hydrateSidebarFromCache();
    unawaited(ref.read(attachmentSweeperProvider).sweepIfDue());
    try {
      await hydrateOutboxMessages();
    } catch (_) {}
    // Rows painted from disk are ciphertext-only. Open them now, from this
    // device's own identity and stored key envelopes, so the list reads before
    // any request — and offline, where no request ever answers.
    unawaited(openCachedPreviews());

    // Only now is the app allowed to touch the network: resolve/verify the
    // real user id, restore the E2EE vault, refresh the sidebar.
    try {
      await ensureCurrentUserId();
    } catch (_) {}
    try {
      await _repo.ensureMessagingDevice();
    } catch (_) {}
    try {
      await ref.read(messageVaultProvider).restoreTrustedIdentity();
    } catch (_) {}
    try {
      await fetchSidebar(silent: hadCache);
    } catch (_) {}
    initRealtime();
    _bootstrapped = true;
    // Private chat (server 0160): take whatever the server is holding for
    // this phone, chat opened or not, before its 7 days run out.
    unawaited(pullPrivatePending());
    // Resumes a recovery restore that was killed mid-run. No-ops when the
    // pending flag is unset, so ordinary launches never pull again.
    unawaited(startHistoryRestoreIfNeeded());
    // Gives back keys other members lost, without waiting for a chat to open.
    unawaited(ref.read(messageVaultProvider).fillKeyGaps(state.currentUserId));
  }

  /// Best-effort user id from purely local sources — current state, whatever
  /// [profileProvider] already resolved, or the on-disk profile cache. Never
  /// touches the network, so cache hydration (which needs an id to key the
  /// sidebar/outbox tables) can never be blocked by a stalled connection.
  /// Returns '' if nothing local is available yet. Callers that need a
  /// guaranteed id (sending, decrypting) use [ensureCurrentUserId] instead,
  /// which is allowed to fall back to the network.
  Future<String> localUserId() async {
    final existing = state.currentUserId.trim();
    if (existing.isNotEmpty) return existing;
    final live = ref.read(profileProvider).valueOrNull?.id.trim() ?? '';
    if (live.isNotEmpty) {
      debugPrint('[ChatCache] localUserId: from live profileProvider: $live');
      state = state.copyWith(currentUserId: live);
      return live;
    }
    final cached = await ref.read(profileRepositoryProvider).getCachedMe();
    final id = cached?.id.trim() ?? '';
    debugPrint(
      '[ChatCache] localUserId: from on-disk profile cache: '
      '"${id.isEmpty ? '<none found>' : id}"',
    );
    if (id.isNotEmpty) state = state.copyWith(currentUserId: id);
    return id;
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
    _restoreCancelled = true;
    _bootstrapped = false;
    _readMarks.clear();
    resetFeedHydration();
    resetOlderPaging();
    resetOlderRefresh();
    state = ChatState(
      currentUserId: clearCurrentUser ? '' : state.currentUserId,
    );
  }

  Future<void> fetchSidebar({bool silent = false}) async {
    if (!silent) state = state.copyWith(sidebarLoading: true);
    try {
      // Bounded so a weak/dead connection fails fast instead of hanging out
      // Dio's full connect+receive timeout — cached rows (if any) stay on
      // screen either way since this only ever clears sidebarLoading, never
      // the dms/channels lists, on failure.
      final userId = await ensureCurrentUserId();
      await syncChatDeletions(ref, userId);
      state = state.copyWith(
        feeds: {
          for (final e in state.feeds.entries)
            e.key: e.value.copyWith(
              messages: messageStore.deletions.filter(e.value.messages),
            ),
        },
        threadRepliesByRoot: {
          for (final e in state.threadRepliesByRoot.entries)
            e.key: messageStore.deletions.filter(e.value),
        },
        searchResults: messageStore.deletions.filter(state.searchResults),
      );
      final data = await _repo.listConversations().timeout(
        firstLoadNetworkTimeout,
      );
      // Groups are sealed exactly like DMs, so both lists are opened.
      final active = state.activeConversationId;
      final stale = <String>{};
      final dms = sortDms(
        _readMarks.apply(
          // A private DM whose newest message the server already let go
          // keeps the preview this phone drew from its own copy.
          await withLocalPreviews(
            keepPrivatePreviews(
              await decryptPreviews(data.dms, userId),
              state.dms,
            ),
            userId,
          ),
          activeId: active,
          stale: stale,
        ),
      );
      final channels = sortChannels(
        _readMarks.apply(
          await withLocalPreviews(
            await decryptPreviews(data.channels, userId),
            userId,
          ),
          activeId: active,
          stale: stale,
        ),
      );
      // The server still counted these unread: its markRead was lost or
      // raced this fetch. Say it again so the next fetch agrees.
      for (final id in stale) {
        unawaited(_repo.markRead(id).catchError((_) {}));
      }
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
      debugPrint(
        '[ChatCache] fetchSidebar: network ok, dms=${dms.length} '
        'channels=${channels.length} currentUserId=${state.currentUserId}',
      );
      prefetchChatListAvatars([...dms, ...channels]);
      await persistSidebar(ChatSidebar(channels: channels, dms: dms));
    } catch (e) {
      // Keep cached rows on network failure — never clear local state
      debugPrint('[ChatCache] fetchSidebar: network threw: $e');
      state = state.copyWith(sidebarLoading: false);
    }
  }

  void setActiveConversation(String? id) {
    if (id != null && !isValidConversationId(id)) return;
    state = state.copyWith(
      activeConversationId: id,
      clearActiveConversation: id == null,
      clearThreadRoot: true,
      clearReplyTo: true,
    );
  }

  /// A conversation screen closed. "Active" goes back to the chat screen still
  /// under it ([next]), or is cleared. It used to stay set after leaving,
  /// because `copyWith` could not null it: messages arriving in a chat nobody
  /// was looking at were acknowledged as read to their sender, the unread
  /// badge never moved and the tray entry was dismissed.
  ///
  /// Checks the current value first, so a leave that lands after the next
  /// screen already claimed "active" changes nothing.
  void leaveConversation(
    String conversationId, {
    String? threadRootId,
    String? next,
  }) {
    if (isDisposed || state.activeConversationId != conversationId) return;
    if (threadRootId != null) {
      // A thread closing leaves its conversation open underneath.
      if (state.threadRootId == threadRootId) setThreadRootId(null);
      return;
    }
    if (next == conversationId) return;
    state = state.copyWith(
      activeConversationId: next,
      clearActiveConversation: next == null,
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
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

final totalUnreadProvider = Provider<int>((ref) {
  final chat = ref.watch(chatProvider);
  // A locked chat's unread would show on the tab while the chat is hidden.
  final locks = ref.watch(chatLocksProvider);
  return totalUnread(
    withoutLockedChats(chat.dms, locks),
    withoutLockedChats(chat.channels, locks),
  );
});

final activeConversationProvider = Provider<ChatConversation?>((ref) {
  final chat = ref.watch(chatProvider);
  return chat.conversationById(chat.activeConversationId);
});
