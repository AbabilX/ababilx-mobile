import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../chat_utils.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'task_card_data.dart';

/// Every task card in one DM, newest first, opened on this device.
final chatTasksProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, conversationId) async {
      final tasks = await ref
          .watch(chatRepositoryProvider)
          .listTasks(conversationId)
          .timeout(firstLoadNetworkTimeout);
      return ref.read(chatProvider.notifier).decryptIfNeeded(tasks);
    });

/// The same task as the open timeline holds it, when it does. A change that
/// arrives over the socket lands there first, so the Tasks page reads it
/// from there instead of going stale.
final liveTaskProvider = Provider.autoDispose
    .family<ChatMessage?, ({String conversationId, String messageId})>((
      ref,
      key,
    ) {
      final feed = ref.watch(
        chatProvider.select((s) => s.feeds[feedKey(key.conversationId)]),
      );
      for (final message in feed?.messages ?? const <ChatMessage>[]) {
        if (message.id == key.messageId) return message;
      }
      return null;
    });

enum TaskFilter { all, open, closed }

List<ChatMessage> filterTasks(List<ChatMessage> tasks, TaskFilter filter) => [
  for (final message in tasks)
    if (switch ((filter, TaskCardData.of(message)?.status.closed)) {
      (_, null) => false,
      (TaskFilter.all, _) => true,
      (TaskFilter.open, final closed) => closed == false,
      (TaskFilter.closed, final closed) => closed == true,
    })
      message,
];
