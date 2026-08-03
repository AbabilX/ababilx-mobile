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
                  child: Column(
                    children: [
                      ThreadRootCard(
                        message: root,
                        conversationId: conversationId,
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
              ],
            ),
          ),
        ),
      )
      .then((_) {
        container.read(chatProvider.notifier).setThreadRootId(null);
      });
}
