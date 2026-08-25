import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/board_models.dart';
import '../shared/kanban_utils.dart';

class KanbanTaskCard extends StatelessWidget {
  const KanbanTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.onLongPress,
    this.dragging = false,
  });

  final KanbanTask task;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final priority = priorityMeta(task.priority);
    final dueMeta = _dueMeta(task.dueDate);

    return Opacity(
      opacity: dragging ? 0.45 : 1,
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.labels.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final label in task.labels)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  parseHexColor(label.color) ?? colors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (task.parentTaskKey != null &&
                      task.parentTaskKey!.isNotEmpty) ...[
                    if (task.labels.isNotEmpty) const SizedBox(height: 6),
                    Text(
                      task.parentTaskKey!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (task.labels.isNotEmpty ||
                      (task.parentTaskKey?.isNotEmpty ?? false))
                    const SizedBox(height: 6),
                  Text(
                    task.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (priority.value != 'none')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priority.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            priority.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: priority.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (dueMeta != null) ...[
                        if (priority.value != 'none') const SizedBox(width: 6),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: dueMeta.overdue
                              ? colors.error
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            dueMeta.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: dueMeta.overdue
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if ((task.taskKey ?? '').isNotEmpty)
                        Text(
                          task.taskKey!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  if ((task.assigneeName ?? '').isNotEmpty ||
                      task.branchName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if ((task.assigneeAvatarUrl ?? '').isNotEmpty)
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: CachedNetworkImageProvider(
                              task.assigneeAvatarUrl!,
                            ),
                          )
                        else if ((task.assigneeName ?? '').isNotEmpty)
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              task.assigneeName!.characters.first.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (task.branchName.isNotEmpty) ...[
                          const Spacer(),
                          Icon(
                            Icons.account_tree_outlined,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              task.branchName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DueMeta {
  const _DueMeta(this.label, this.overdue);
  final String label;
  final bool overdue;
}

_DueMeta? _dueMeta(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final due = DateTime.parse(iso);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final overdue = dueDay.isBefore(today);
    return _DueMeta(DateFormat('MMM d').format(due), overdue);
  } catch (_) {
    return null;
  }
}
