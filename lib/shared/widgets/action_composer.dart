import 'package:flutter/material.dart';

class ActionComposer extends StatelessWidget {
  const ActionComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.busy,
    required this.canSend,
    required this.actions,
    required this.onSend,
    this.header,
    this.pending,
    this.minLines = 1,
    this.maxLines = 6,
    this.showHandle = false,
    this.embedded = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool busy;
  final bool canSend;
  final List<Widget> actions;
  final VoidCallback onSend;
  final Widget? header;
  final Widget? pending;
  final int minLines;
  final int maxLines;
  final bool showHandle;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHandle)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ?header,
        ?pending,
        TextField(
          controller: controller,
          focusNode: focusNode,
          minLines: minLines,
          maxLines: maxLines,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          ),
          textInputAction: TextInputAction.newline,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 6, 6),
          child: Row(
            children: [
              ...actions,
              const Spacer(),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Send',
                  onPressed: canSend ? onSend : null,
                  icon: Icon(
                    Icons.send_rounded,
                    size: 26,
                    color: canSend
                        ? colors.primary
                        : colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Material(
      color: embedded ? colors.surfaceContainerLow : colors.surface,
      borderRadius: embedded
          ? BorderRadius.circular(18)
          : const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      elevation: embedded ? 0 : 8,
      child: embedded ? content : SafeArea(top: false, child: content),
    );
  }
}

class ComposerActionButton extends StatelessWidget {
  const ComposerActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
