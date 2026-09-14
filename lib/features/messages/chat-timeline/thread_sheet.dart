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
                  child: LayoutBuilder(
                    builder: (context, constraints) => Column(
                      children: [
                        // The root is capped and scrolls on its own. A long
                        // root (a webhook order, a pasted log) used to take
                        // its full height, so once the keyboard shrank the
                        // screen the composer was pushed off the bottom. The
                        // replies + composer always keep at least 200px.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: (constraints.maxHeight - 200).clamp(
                              0.0,
                              constraints.maxHeight * 0.4,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: ThreadRootCard(
                              message: root,
                              conversationId: conversationId,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ChatTimeline(
                            conversationId: conversationId,
                            threadRootId: root.id,
                          ),
                        ),
                      ],
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
