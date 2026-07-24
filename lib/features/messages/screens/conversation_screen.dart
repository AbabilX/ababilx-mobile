import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-header/index.dart';
import '../chat-timeline/index.dart';
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
      ref.read(chatProvider.notifier).setActiveConversation(widget.conversationId);
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

    return Scaffold(
      appBar: conversation != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: ChatHeader(conversation: conversation),
            )
          : AppBar(title: const Text('Conversation')),
      body: ChatTimeline(
        conversationId: widget.conversationId,
        threadRootId: widget.threadRootId,
      ),
    );
  }
}
