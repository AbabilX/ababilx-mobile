import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/chat_message.dart';
import '../chat-pins/pinned_messages_chrome.dart';
import '../../../shared/widgets/app_capsule.dart';
import 'task_card_data.dart';
import 'task_icons.dart';
import 'task_list_item.dart';
import 'task_list_notice.dart';
import 'task_list_provider.dart';
import 'task_strings.dart';

/// Every task the two people in a DM share, in one place: filter by open or
/// closed, change priority and status right here, or jump to the card in the
/// chat. Choosing "Show in chat" answers the message id to whoever opened it.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<TaskListScreen> {
  TaskFilter _filter = TaskFilter.all;

  /// Cards changed on this page, by id: the fetched list is a snapshot.
  final _changed = <String, ChatMessage>{};

  TaskListKey get _key =>
      (conversationId: widget.conversationId, filter: _filter);

  @override
  Widget build(BuildContext context) {
    final s = TaskStrings.of(ref.watch(appLanguageProvider));
    final top = MediaQuery.viewPaddingOf(context).top + 64;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: Column(
                children: [
                  _filters(s),
                  Expanded(child: _body(ref.watch(chatTasksProvider(_key)), s)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PinnedMessagesTopBar(title: s.tasks, bottomPadding: 12),
          ),
        ],
      ),
    );
  }

  Widget _filters(TaskStrings s) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (filter, label, icon) in [
            (TaskFilter.all, s.all, TaskIcons.task),
            (TaskFilter.open, s.open, TaskIcons.status(TaskStatus.todo)),
            (TaskFilter.closed, s.closed, TaskIcons.taskDone),
          ])
            AppCapsule(
              label: label,
              icon: icon,
              selected: _filter == filter,
              onTap: () => setState(() => _filter = filter),
            ),
        ],
      ),
    ),
  );

  Widget _body(AsyncValue<TaskPages> tasks, TaskStrings s) {
    final pages = tasks.valueOrNull;
    if (pages == null) {
      if (!tasks.hasError) {
        return const Center(child: CircularProgressIndicator());
      }
      return TaskListNotice(
        title: s.loadFailed,
        action: AppCapsule(
          label: s.retry,
          onTap: () => ref.invalidate(chatTasksProvider(_key)),
        ),
      );
    }
    final shown = filterTasks([
      for (final message in pages.tasks) _changed[message.id] ?? message,
    ], _filter);
    if (shown.isEmpty && !pages.hasMore) {
      return pages.tasks.isEmpty && _filter == TaskFilter.all
          ? TaskListNotice(title: s.emptyTitle, body: s.emptyBody)
          : TaskListNotice(title: s.emptyFilter);
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.viewPaddingOf(context).bottom + 24,
      ),
      // One row past the end while more is on the server: building it is
      // what asks for the next page.
      itemCount: shown.length + (pages.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == shown.length) {
          final notifier = ref.read(chatTasksProvider(_key).notifier);
          if (pages.moreFailed) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: AppCapsule(label: s.retry, onTap: notifier.loadMore),
              ),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => notifier.loadMore(),
          );
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return TaskListItem(
          key: ValueKey(shown[index].id),
          message: shown[index],
          onChanged: (next) => setState(() => _changed[next.id] = next),
          onOpen: () => context.pop(shown[index].id),
        );
      },
    );
  }
}
