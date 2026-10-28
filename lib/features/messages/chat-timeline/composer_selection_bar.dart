import 'dart:async';

import 'package:flutter/material.dart';

/// How long a selection has to sit still before the bar opens.
///
/// Dragging a handle moves the selection on every frame. Opening on each of
/// those frames fights the magnifier, which hides the bar while the finger
/// is down. Waiting until the range stops moving opens it once.
const selectionBarDelay = Duration(milliseconds: 280);

/// Reopens the composer selection bar whenever a range is selected.
///
/// A long press shows the bar on its own. Growing that word into a line by
/// dragging the handles does not: Android only opens the bar again after a
/// double tap. This listens to the field and opens it for any range.
class ComposerSelectionBar extends StatefulWidget {
  const ComposerSelectionBar({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  @override
  State<ComposerSelectionBar> createState() => _ComposerSelectionBarState();
}

class _ComposerSelectionBarState extends State<ComposerSelectionBar> {
  Timer? _open;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
  }

  @override
  void didUpdateWidget(ComposerSelectionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_schedule);
    widget.controller.addListener(_schedule);
  }

  @override
  void dispose() {
    _open?.cancel();
    widget.controller.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    _open?.cancel();
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    _open = Timer(selectionBarDelay, _show);
  }

  void _show() {
    if (!mounted) return;
    // The selection overlay is built on the frame after the range changes.
    // Opening in the timer itself finds no overlay and the bar stays down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selection = widget.controller.selection;
      if (!selection.isValid || selection.isCollapsed) return;
      _editorOf(context)?.showToolbar();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

EditableTextState? _editorOf(BuildContext context) {
  EditableTextState? found;
  void visit(Element element) {
    if (found != null) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      found = element.state as EditableTextState;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  return found;
}
