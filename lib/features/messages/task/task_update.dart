import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat_utils.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'task_card_data.dart';
import 'task_strings.dart';

/// Moves a task card's priority or status: the card changes at once, then
/// the server is told, and a refusal puts the old value back. Answers the
/// card as it now stands, or null when the change did not hold.
///
/// The settled copy is not written to disk from here — the server sends the
/// change back over the socket with its revision, and that copy is stored.
Future<ChatMessage?> changeTask(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message, {
  TaskPriority? priority,
  TaskStatus? status,
}) async {
  final notifier = ref.read(chatProvider.notifier);
  final repository = ref.read(chatRepositoryProvider);
  final strings = TaskStrings.of(ref.read(appLanguageProvider));
  final conversationId = message.conversationId;
  final moved = message.copyWith(
    meta: taskMetaWith(message, priority: priority, status: status),
  );
  notifier.updateFeedMessage(conversationId, moved);
  try {
    final saved = await repository.updateTask(
      message.id,
      priority: priority?.wire,
      status: status?.wire,
    );
    final settled = moved.copyWith(meta: saved.meta);
    notifier.updateFeedMessage(conversationId, settled);
    return settled;
  } catch (_) {
    // Put the old value back only where our own change still stands: the
    // other person may have moved the task while this was in flight.
    final current = ref
        .read(chatProvider)
        .feeds[feedKey(conversationId)]
        ?.messages
        .where((m) => m.id == message.id)
        .firstOrNull;
    if (current == null || current == moved) {
      notifier.updateFeedMessage(conversationId, message);
    }
    if (context.mounted) {
      showAppToast(context, strings.updateFailed, isError: true);
    }
    return null;
  }
}
