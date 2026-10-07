import 'package:flutter/material.dart';

import 'task_card_data.dart';

/// The tint each priority and status is drawn in. Meaning, not theme: "done"
/// is green and "blocked" is red in either theme, a shade apart so each
/// reads on its own surface.
class TaskPalette {
  const TaskPalette._(this._dark, this._scheme);

  factory TaskPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    return TaskPalette._(
      theme.brightness == Brightness.dark,
      theme.colorScheme,
    );
  }

  final bool _dark;
  final ColorScheme _scheme;

  Color _pick(int light, int dark) => Color(_dark ? dark : light);

  Color get _grey => _scheme.onSurfaceVariant;
  Color get _blue => _pick(0xFF2563EB, 0xFF7AA7FF);
  Color get _amber => _pick(0xFFB45309, 0xFFFBBF24);
  Color get _purple => _pick(0xFF7C3AED, 0xFFB79CFF);
  Color get _red => _pick(0xFFDC2626, 0xFFFF8A80);
  Color get _green => _pick(0xFF15803D, 0xFF4ADE80);

  Color priority(TaskPriority p) => switch (p) {
    TaskPriority.low => _grey,
    TaskPriority.medium => _blue,
    TaskPriority.high => _amber,
    TaskPriority.urgent => _red,
  };

  Color status(TaskStatus s) => switch (s) {
    TaskStatus.todo => _grey,
    TaskStatus.inProgress => _blue,
    TaskStatus.review => _purple,
    TaskStatus.blocked => _red,
    TaskStatus.done => _green,
    TaskStatus.cancelled => _grey,
  };
}
