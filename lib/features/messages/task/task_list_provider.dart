import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../chat_utils.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'task_card_data.dart';

enum TaskFilter { all, open, closed }

/// What the Tasks page holds so far: the pages read, and where the next one
/// starts. [nextCursor] is null once the last page is in.
class TaskPages {
  const TaskPages({
    required this.tasks,
    this.nextCursor,
    this.loadingMore = false,
    this.moreFailed = false,
  });

  final List<ChatMessage> tasks;
  final String? nextCursor;
  final bool loadingMore;

  /// The last read of a further page failed. The page says so and waits for
  /// a tap: asking again on its own would loop for as long as it is offline.
  final bool moreFailed;

  bool get hasMore => nextCursor != null;
}

typedef TaskListKey = ({String conversationId, TaskFilter filter});

/// The task cards of one DM under one filter, newest first, opened on this
/// device and read a page at a time: each is a whole message, and a
/// description may be hundreds of kilobytes.
class TaskPagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<TaskPages, TaskListKey> {
  @override
  Future<TaskPages> build(TaskListKey arg) async {
    final page = await _read(null).timeout(firstLoadNetworkTimeout);
    return TaskPages(tasks: page.tasks, nextCursor: page.nextCursor);
  }

  Future<({List<ChatMessage> tasks, String? nextCursor})> _read(
    String? cursor,
  ) async {
    final page = await ref
        .read(chatRepositoryProvider)
        .listTasks(
          arg.conversationId,
          cursor: cursor,
          state: switch (arg.filter) {
            TaskFilter.all => null,
            TaskFilter.open => 'open',
            TaskFilter.closed => 'closed',
          },
        );
    final opened = await ref
        .read(chatProvider.notifier)
        .decryptIfNeeded(page.tasks);
    return (tasks: opened, nextCursor: page.nextCursor);
  }

  /// Reads the next page onto the end. A failure leaves what is shown and
  /// the cursor in place, and marks [TaskPages.moreFailed].
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || current.loadingMore) return;
    state = AsyncData(
      TaskPages(tasks: current.tasks, nextCursor: cursor, loadingMore: true),
    );
    try {
      final page = await _read(cursor);
      final known = {for (final task in current.tasks) task.id};
      state = AsyncData(
        TaskPages(
          tasks: [
            ...current.tasks,
            for (final task in page.tasks)
              if (known.add(task.id)) task,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      state = AsyncData(
        TaskPages(tasks: current.tasks, nextCursor: cursor, moreFailed: true),
      );
    }
  }
}

final chatTasksProvider = AsyncNotifierProvider.autoDispose
    .family<TaskPagesNotifier, TaskPages, TaskListKey>(TaskPagesNotifier.new);

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

/// The filter again, over what is on screen: a task closed on this page
/// leaves the Open list at once, without a second request.
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
