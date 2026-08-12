import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../chat-header/index.dart';
import '../chat-timeline/index.dart';
import '../nav_back.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/message_vault_gate.dart';
import '../providers/chat_provider.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatProvider.notifier)
          .setActiveConversation(widget.conversationId);
      if (widget.threadRootId != null) {
        ref.read(chatProvider.notifier).setThreadRootId(widget.threadRootId);
      }
    });
  }

  @override
  void dispose() {
    ref.read(chatProvider.notifier).setActiveConversation(null);
    ref.read(chatProvider.notifier).setThreadRootId(null);
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
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOrGoMessages(context);
      },
      child: Scaffold(
        body: conversation?.isDm == true && !vault.isUnlocked
            ? Column(
                children: [
                  ChatHeader(conversation: conversation!),
                  Expanded(
                    child: MessageVaultGate(
                      onUnlocked: () {
                        ref
                            .read(chatProvider.notifier)
                            .loadFeed(widget.conversationId, force: true);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              )
            : ChatTimeline(
                conversationId: widget.conversationId,
                threadRootId: widget.threadRootId,
                header: conversation != null
                    ? ChatHeader(conversation: conversation)
                    : const _FallbackHeader(),
              ),
      ),
    );
  }
}

class _FallbackHeader extends StatelessWidget {
  const _FallbackHeader();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: NavigationToolbar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => popOrGoMessages(context),
            ),
            middle: const Text(
              'Conversation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            centerMiddle: true,
          ),
        ),
      ),
    );
  }
}
