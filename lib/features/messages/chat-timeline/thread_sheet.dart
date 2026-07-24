import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'chat_timeline.dart';

void openThreadSheet(
  BuildContext context,
  String conversationId,
  ChatMessage root,
) {
  final container = ProviderScope.containerOf(context);
  container.read(chatProvider.notifier).setThreadRootId(root.id);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Thread',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
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
  ).whenComplete(() {
    container.read(chatProvider.notifier).setThreadRootId(null);
  });
}
