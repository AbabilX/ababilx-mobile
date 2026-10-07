import 'package:flutter/material.dart';

import '../chat_icon.dart';
import '../../../shared/widgets/app_capsule.dart';
import 'task_icons.dart';

/// A task card's dropdown: a capsule stating the value in its own tint, with
/// its glyph and a chevron. Tapping opens the chooser sheet. With no [onTap]
/// it only states the value.
class TaskPill extends StatelessWidget {
  const TaskPill({
    super.key,
    required this.caption,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  /// What the dropdown is — "Priority", "Status" — read out, not drawn: the
  /// glyph and the value already say it.
  final String caption;
  final String label;
  final List<List<dynamic>> icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: caption,
    value: label,
    child: AppCapsule(
      label: label,
      icon: icon,
      tint: color,
      selected: true,
      expand: true,
      onTap: onTap,
      trailing: onTap == null
          ? null
          : ChatIcon(
              TaskIcons.chevron,
              size: 16,
              color: color,
              strokeWidth: 1.8,
            ),
    ),
  );
}
