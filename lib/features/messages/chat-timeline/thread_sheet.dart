import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'chat_timeline.dart';
import 'thread_header.dart';
import 'thread_root_card.dart';

void openThreadSheet(
  BuildContext context,
  String conversationId,
  ChatMessage root,
) {
  final container = ProviderScope.containerOf(context);
  container.read(chatProvider.notifier).setThreadRootId(root.id);
  final conversation = container
      .read(chatProvider)
      .conversationById(conversationId);

  Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Column(
              children: [
                ThreadHeader(conversation: conversation),
                Expanded(
                  // The root scrolls with the replies, as the list's oldest
                  // row. It used to sit in its own box capped at 40% of the
                  // screen, so on a short phone a long root's "Read more"
                  // fell below that box and read as unreachable. In the list
                  // it is always reachable, and the composer still keeps its
                  // place at the bottom however long the root is.
                  child: ChatTimeline(
                    conversationId: conversationId,
                    threadRootId: root.id,
                    leading: ThreadRootCard(
                      message: root,
                      conversationId: conversationId,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
      .then((_) {
        container.read(chatProvider.notifier).setThreadRootId(null);
      });
}
