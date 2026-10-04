import 'package:flutter/material.dart';

import '../chat_icon.dart';

/// What a [SelectionAction] does — the two bars pick their buttons by it.
enum SelectionActionKind { reply, forward, save, copy, edit, delete }

/// One button of the selection bars.
class SelectionAction {
  const SelectionAction({
    required this.kind,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final SelectionActionKind kind;

  /// Hugeicons path data, drawn through [ChatIcon].
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onPressed;
}

/// The floating pill every part of the selection bars is drawn on. It sits
/// over the timeline, so it carries its own fill and shadow.
class SelectionCapsule extends StatelessWidget {
  const SelectionCapsule({super.key, required this.child, this.onTap});

  static const height = 48.0;

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 3,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: height, child: child),
      ),
    );
  }
}

/// An icon-only button inside a capsule; the label is its tooltip.
class SelectionIconButton extends StatelessWidget {
  const SelectionIconButton({super.key, required this.item});

  final SelectionAction item;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: InkResponse(
        onTap: item.onPressed,
        radius: 22,
        child: SizedBox(
          width: 42,
          height: SelectionCapsule.height,
          child: Center(
            child: ChatIcon(
              item.icon,
              color: Theme.of(context).colorScheme.onSurface,
              strokeWidth: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
