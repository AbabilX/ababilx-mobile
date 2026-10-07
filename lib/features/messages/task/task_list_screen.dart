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

  @override
  Widget build(BuildContext context) {
    final s = TaskStrings.of(ref.watch(appLanguageProvider));
    final tasks = ref.watch(chatTasksProvider(widget.conversationId));
    final top = MediaQuery.viewPaddingOf(context).top + 64;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: _body(tasks, s),
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

  Widget _body(AsyncValue<List<ChatMessage>> tasks, TaskStrings s) {
    if (tasks.isLoading && !tasks.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tasks.hasError && !tasks.hasValue) {
      return _Notice(
        title: s.loadFailed,
        action: AppCapsule(
          label: s.retry,
          onTap: () => ref.invalidate(chatTasksProvider(widget.conversationId)),
        ),
      );
    }
    final all = [
      for (final message in tasks.value ?? const <ChatMessage>[])
        _changed[message.id] ?? message,
    ];
    if (all.isEmpty) return _Notice(title: s.emptyTitle, body: s.emptyBody);
    final shown = filterTasks(all, _filter);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
        Expanded(
          child: shown.isEmpty
              ? _Notice(title: s.emptyFilter)
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    MediaQuery.viewPaddingOf(context).bottom + 24,
                  ),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => TaskListItem(
                    key: ValueKey(shown[index].id),
                    message: shown[index],
                    onChanged: (next) =>
                        setState(() => _changed[next.id] = next),
                    onOpen: () => context.pop(shown[index].id),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, this.body, this.action});

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
