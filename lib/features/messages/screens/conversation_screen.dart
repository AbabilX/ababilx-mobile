import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/ws_client.dart';
import '../../../shared/widgets/portrait_lock_scope.dart';
import '../chat-focus/chat_focus_reporter.dart';
import '../chat-header/index.dart';
import '../chat-select/message_selection.dart';
import '../chat-timeline/index.dart';
import '../data/models/chat_models.dart';
import '../nav_back.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/message_vault_gate.dart';
import '../providers/chat_provider.dart';
import '../wallpaper/chat_wallpaper_background.dart';
import 'conversation_states.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.threadRootId,
  });

  final String conversationId;
  final String? threadRootId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  bool _ready = false;
  bool _vaultChecked = false;
  late final ChatFocusReporter _focus = ChatFocusReporter(
    ws: ref.read(wsClientProvider),
    conversationId: widget.conversationId,
  );

  @override
  void initState() {
    super.initState();
    // Opened from a push notification this screen can mount before anything
    // else has loaded chat, so it starts the bootstrap itself instead of
    // racing whatever ChatStoreSync is doing.
    _prepare();
    // No buzz for a message landing in the chat being read.
    _focus.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(chatProvider.notifier)
          .setActiveConversation(widget.conversationId);
      if (widget.threadRootId != null) {
        ref.read(chatProvider.notifier).setThreadRootId(widget.threadRootId);
      }
    });
  }

  Future<void> _prepare() async {
    // Opened straight from a notification, this screen is the first thing to
    // mount, so it has to restore the E2EE identity itself — MessagesScreen
    // does it for the list route. Without this a DM opened from a push showed
    // the PIN gate every single time, even though the identity was sitting in
    // this device's secure storage. Local read only, no server round-trip.
    final vault = ref.read(messageVaultProvider);
    if (!vault.isUnlocked) {
      try {
        await vault.restoreTrustedIdentityOffline();
      } catch (_) {
        // Still locked — the gate below asks for the PIN, as before.
      }
    }
    if (mounted) setState(() => _vaultChecked = true);
    try {
      await ref.read(chatProvider.notifier).ensureReady();
    } catch (_) {
      // Errors surface as an unavailable conversation below.
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _retry() async {
    setState(() => _ready = false);
    await ref.read(chatProvider.notifier).fetchSidebar();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _focus.dispose();
    // Arrivals over the socket move the read marker as they land; this catches
    // the ones that came in with the socket down, so backing out of a chat
    // never leaves it showing unread messages the reader has just seen.
    if (widget.threadRootId == null) {
      ref
          .read(chatProvider.notifier)
          .markConversationRead(widget.conversationId)
          .ignore();
    }
    ref.read(chatProvider.notifier).setActiveConversation(null);
    ref.read(chatProvider.notifier).setThreadRootId(null);
    // Leaving the chat leaves the mode: the bars belong to this screen, and a
    // selection that survived it would be waiting on the next visit.
    ref.read(messageSelectionProvider.notifier).clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final conversation = chat.conversationById(widget.conversationId);
    final vault = ref.read(messageVaultProvider);

    // Prefer stack pop when list→chat push; else Messages home (notification go).
    final canPop =
        GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();
    // Back leaves multi-select before it leaves the conversation — Signal's
    // `handleBackPressed`, where `isInActionMode` is handled above the pop.
    final selecting = ref
        .watch(messageSelectionProvider)
        .isActiveIn(widget.conversationId);
    // Chat list, chat body + IME, and the calls tab are portrait-only.
    // Unlock when the last PortraitLockScope leaves so /call can rotate.
    return PortraitLockScope(
      child: PopScope(
        canPop: canPop && !selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (selecting) {
            ref.read(messageSelectionProvider.notifier).clear();
            return;
          }
          popOrGoMessages(context);
        },
        // The wallpaper paints inside the body, on top of the Scaffold's own
        // background and under the chat — so with no wallpaper set nothing
        // changes, and the Scaffold keeps painting the theme colour.
        child: Scaffold(
          body: ChatWallpaperBackground(
            conversationId: widget.conversationId,
            child: _body(conversation, vault),
          ),
        ),
      ),
    );
  }

  Widget _body(ChatConversation? conversation, MessageVault vault) {
    if (conversation == null) {
      return _ready
          ? ConversationUnavailable(onRetry: _retry)
          : const ConversationLoading();
    }
    if (conversation.isEncrypted && !vault.isUnlocked) {
      return Column(
        children: [
          ChatHeader(conversation: conversation),
          Expanded(
            // The restore is a secure-storage read; showing the PIN gate
            // before it answers would flash a prompt the user never needs.
            child: !_vaultChecked
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : SafeArea(
                    top: false,
                    child: MessageVaultGate(
                      onUnlocked: () {
                        ref
                            .read(chatProvider.notifier)
                            .loadFeed(widget.conversationId, force: true);
                        setState(() {});
                      },
                    ),
                  ),
          ),
        ],
      );
    }
    return ChatTimeline(
      conversationId: widget.conversationId,
      threadRootId: widget.threadRootId,
      header: ChatHeader(conversation: conversation),
    );
  }
}
