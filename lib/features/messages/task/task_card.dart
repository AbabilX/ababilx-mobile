import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-timeline/message_body.dart';
import '../chat-timeline/message_bubble.dart';
import '../chat_icon.dart';
import '../data/models/chat_message.dart';
import 'task_card_data.dart';
import 'task_choice_sheet.dart';
import 'task_icons.dart';
import 'task_palette.dart';
import 'task_pill.dart';
import 'task_strings.dart';
import 'task_update.dart';

/// A task card: label, title, description, files, then the two dropdowns —
/// priority and status — that either person in the DM may change.
///
/// Drawn inside a message bubble in the timeline and on its own surface on
/// the Tasks page; [footer] is the bubble's time and ticks.
class TaskCard extends ConsumerWidget {
  const TaskCard({
    super.key,
    required this.message,
    required this.task,
    required this.colors,
    this.footer,
    this.onChanged,
  });

  final ChatMessage message;
  final TaskCardData task;
  final BubbleColors colors;
  final Widget? footer;

  /// The card after a change held — for a list that keeps its own copy.
  final ValueChanged<ChatMessage>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = TaskStrings.of(ref.watch(appLanguageProvider));
    final palette = TaskPalette.of(context);
    final text = taskText(message);
    final closed = task.status.closed;
    final hasFiles =
        message.attachments.isNotEmpty || message.pendingAttachments.isNotEmpty;
    // A card still on its way has no server row to change yet.
    final live = !message.isPending;

    Future<void> change({TaskPriority? priority, TaskStatus? status}) async {
      final next = await changeTask(
        context,
        ref,
        message,
        priority: priority,
        status: status,
      );
      if (next != null) onChanged?.call(next);
    }

    Future<void> pickPriority() async {
      final picked = await showTaskChoiceSheet<TaskPriority>(
        context,
        title: strings.priority,
        selected: task.priority,
        choices: [
          for (final p in TaskPriority.values)
            TaskChoice(
              value: p,
              label: strings.priorityName(p),
              icon: TaskIcons.priority(p),
              color: palette.priority(p),
            ),
        ],
      );
      if (picked != null && picked != task.priority) {
        await change(priority: picked);
      }
    }

    Future<void> pickStatus() async {
      final picked = await showTaskChoiceSheet<TaskStatus>(
        context,
        title: strings.status,
        selected: task.status,
        choices: [
          for (final s in TaskStatus.values)
            TaskChoice(
              value: s,
              label: strings.statusName(s),
              icon: TaskIcons.status(s),
              color: palette.status(s),
            ),
        ],
      );
      if (picked != null && picked != task.status) await change(status: picked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(
              closed ? TaskIcons.taskDone : TaskIcons.task,
              size: 16,
              color: palette.status(task.status),
              strokeWidth: 1.6,
            ),
            const SizedBox(width: 6),
            Text(
              strings.cardLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          text.title,
          style: TextStyle(
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: closed ? colors.muted : colors.foreground,
            decoration: task.status == TaskStatus.cancelled
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        if (text.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            text.description,
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: colors.foreground.withValues(alpha: closed ? 0.6 : 0.85),
            ),
          ),
        ],
        if (hasFiles) ...[
          const SizedBox(height: 8),
          // The message's own files, drawn by the timeline's renderer with
          // the text left out — the card has already shown it.
          MessageBody(
            message: message.copyWith(body: ''),
            colors: colors,
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TaskPill(
                caption: strings.priority,
                label: strings.priorityName(task.priority),
                icon: TaskIcons.priority(task.priority),
                color: palette.priority(task.priority),
                onTap: live ? pickPriority : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TaskPill(
                caption: strings.status,
                label: strings.statusName(task.status),
                icon: TaskIcons.status(task.status),
                color: palette.status(task.status),
                onTap: live ? pickStatus : null,
              ),
            ),
          ],
        ),
        if (footer != null) ...[
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: footer),
        ],
      ],
    );
  }
}
