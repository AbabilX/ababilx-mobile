import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Focused two-level composer matching Slack mobile: writing area on top,
/// quick actions below, and a persistent send action at the far right.
class ComposerSlackField extends StatelessWidget {
  const ComposerSlackField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.sending,
    required this.canSend,
    required this.expanded,
    required this.onAttach,
    required this.onFormat,
    required this.onEmoji,
    required this.onMention,
    required this.onExpand,
    required this.onSend,
    required this.attachTooltip,
    required this.formatTooltip,
    required this.emojiTooltip,
    required this.mentionTooltip,
    required this.expandTooltip,
    required this.sendTooltip,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool sending;
  final bool canSend;
  final bool expanded;
  final VoidCallback onAttach;
  final VoidCallback onFormat;
  final VoidCallback onEmoji;
  final VoidCallback onMention;
  final VoidCallback onExpand;
  final VoidCallback onSend;
  final String attachTooltip;
  final String formatTooltip;
  final String emojiTooltip;
  final String mentionTooltip;
  final String expandTooltip;
  final String sendTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: expanded ? 5 : 2,
            maxLines: expanded ? 10 : 6,
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: muted,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            ),
            textInputAction: TextInputAction.newline,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
            child: Row(
              children: [
                _CircleAction(
                  tooltip: attachTooltip,
                  onPressed: sending ? null : onAttach,
                  child: ChatIcon(
                    HugeIcons.strokeRoundedAdd01,
                    size: 25,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 8),
                _ToolbarAction(
                  tooltip: formatTooltip,
                  onPressed: sending ? null : onFormat,
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      color: muted,
                      fontSize: 23,
                      height: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _ToolbarAction(
                  tooltip: emojiTooltip,
                  onPressed: sending ? null : onEmoji,
                  child: Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    color: muted,
                    size: 26,
                  ),
                ),
                _ToolbarAction(
                  tooltip: mentionTooltip,
                  onPressed: sending ? null : onMention,
                  child: Text(
                    '@',
                    style: TextStyle(
                      color: muted,
                      fontSize: 29,
                      height: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _ToolbarAction(
                  tooltip: expandTooltip,
                  onPressed: sending ? null : onExpand,
                  child: Icon(
                    expanded
                        ? Icons.close_fullscreen_rounded
                        : Icons.edit_outlined,
                    color: muted,
                    size: 25,
                  ),
                ),
                const Spacer(),
                if (sending)
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
                    tooltip: sendTooltip,
                    onPressed: canSend ? onSend : null,
                    icon: Icon(
                      Icons.send_rounded,
                      size: 31,
                      color: canSend
                          ? colors.primary
                          : muted.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 46, height: 46, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: child,
  );
}
