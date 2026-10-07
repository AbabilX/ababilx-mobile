import 'package:flutter/material.dart';

import '../chat_icon.dart';
import 'task_icons.dart';

/// One row of a task chooser.
class TaskChoice<T> {
  const TaskChoice({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final T value;
  final String label;
  final List<List<dynamic>> icon;
  final Color color;
}

/// The list behind a task card's dropdown, as a bottom sheet. Answers the
/// row picked, or null when the sheet was dismissed.
Future<T?> showTaskChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<TaskChoice<T>> choices,
  required T selected,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) {
    final theme = Theme.of(sheet);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            for (final choice in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _Row(
                  choice: choice,
                  picked: choice.value == selected,
                  onTap: () => Navigator.of(sheet).pop(choice.value),
                ),
              ),
          ],
        ),
      ),
    );
  },
);

/// A capsule row: the value's glyph and name in its tint, a tick when it is
/// the one in force.
class _Row<T> extends StatelessWidget {
  const _Row({required this.choice, required this.picked, required this.onTap});

  final TaskChoice<T> choice;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: picked
          ? choice.color.withValues(alpha: 0.15)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              ChatIcon(
                choice.icon,
                size: 20,
                color: choice.color,
                strokeWidth: 1.6,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  choice.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: picked ? FontWeight.w600 : FontWeight.w500,
                    color: picked ? choice.color : scheme.onSurface,
                  ),
                ),
              ),
              if (picked)
                ChatIcon(
                  TaskIcons.picked,
                  size: 20,
                  color: choice.color,
                  strokeWidth: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
