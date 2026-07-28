import 'package:flutter/material.dart';

import '../data/models/board_models.dart';
import '../shared/kanban_utils.dart';
import 'create_task_field.dart';
import 'kanban_task_card.dart';

class KanbanColumnView extends StatelessWidget {
  const KanbanColumnView({
    super.key,
    required this.column,
    required this.tasks,
    required this.onOpenTask,
    required this.onMoveTask,
    this.onCreateTask,
    this.createDisabled = false,
    this.draggingTaskId,
  });

  final KanbanColumn column;
  final List<KanbanTask> tasks;
  final ValueChanged<KanbanTask> onOpenTask;
  final void Function(KanbanTask task, String toStatus) onMoveTask;
  final Future<void> Function(String title)? onCreateTask;
  final bool createDisabled;
  final String? draggingTaskId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = columnAccent(column);

    return DragTarget<KanbanTask>(
      onWillAcceptWithDetails: (details) =>
          details.data.status != column.key,
      onAcceptWithDetails: (details) =>
          onMoveTask(details.data, column.key),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: kanbanColumnWidth,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight
                  ? accent
                  : colors.outlineVariant.withValues(alpha: 0.6),
              width: highlight ? 1.5 : 0.9,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: accent, width: 3)),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        column.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${tasks.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    if (onCreateTask != null)
                      CreateTaskField(
                        disabled: createDisabled,
                        onCreate: onCreateTask!,
                      ),
                    for (final task in tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LongPressDraggable<KanbanTask>(
                          data: task,
                          feedback: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: kanbanColumnWidth - 16,
                              child: KanbanTaskCard(
                                task: task,
                                onTap: () {},
                                dragging: false,
                              ),
                            ),
                          ),
                          childWhenDragging: KanbanTaskCard(
                            task: task,
                            onTap: () => onOpenTask(task),
                            dragging: true,
                          ),
                          child: KanbanTaskCard(
                            task: task,
                            onTap: () => onOpenTask(task),
                            dragging: draggingTaskId == task.id,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
