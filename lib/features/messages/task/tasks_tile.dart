import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-details/details_tile.dart';
import '../chat_icon.dart';
import 'task_icons.dart';
import 'task_strings.dart';

/// "Tasks" on a DM's details screen: every task card the two people share.
/// Choosing one there closes this screen with its id, and the chat under it
/// walks to the card — the way a pin does.
class TasksTile extends ConsumerWidget {
  const TasksTile({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DetailsTile(
    icon: const ChatIcon(TaskIcons.task),
    title: TaskStrings.of(ref.watch(appLanguageProvider)).tasks,
    trailing: const ChatIcon(TaskIcons.open, size: 18),
    onTap: () async {
      final messageId = await context.push<String>(
        '/messages/$conversationId/tasks',
      );
      if (messageId != null && context.mounted) context.pop(messageId);
    },
  );
}
