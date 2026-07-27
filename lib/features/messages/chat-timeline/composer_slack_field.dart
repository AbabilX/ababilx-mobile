import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Focused two-level composer: writing area on top, quick actions below.
class ComposerSlackField extends StatelessWidget {
  const ComposerSlackField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.sending,
    required this.canSend,
    required this.expanded,
    required this.isGroup,
    required this.onAttach,
    required this.onVoice,
    required this.onShareContact,
    required this.onMention,
    required this.onExpand,
    required this.onSend,
    required this.attachTooltip,
    required this.voiceTooltip,
    required this.shareContactTooltip,
    required this.mentionTooltip,
    required this.expandTooltip,
    required this.sendLabel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool sending;
  final bool canSend;
  final bool expanded;

  /// Channel/group — show @ mention beside share-contact.
  final bool isGroup;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final VoidCallback onShareContact;
  final VoidCallback onMention;
  final VoidCallback onExpand;
  final VoidCallback onSend;
  final String attachTooltip;
  final String voiceTooltip;
  final String shareContactTooltip;
  final String mentionTooltip;
  final String expandTooltip;
  final String sendLabel;

  static const double _actionSize = 40;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    return ColoredBox(
      color: colors.surface,
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
            minLines: expanded ? 5 : 1,
            maxLines: expanded ? 10 : 6,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: muted,
                fontSize: 17,
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
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                _ToolbarAction(
                  tooltip: attachTooltip,
                  onPressed: sending ? null : onAttach,
                  child: ChatIcon(
                    HugeIcons.strokeRoundedAdd01,
                    size: _iconSize,
                    color: muted,
                  ),
                ),
                _ToolbarAction(
                  tooltip: voiceTooltip,
                  onPressed: sending ? null : onVoice,
                  child: ChatIcon(
                    HugeIcons.strokeRoundedMic01,
                    size: _iconSize,
                    color: muted,
                  ),
                ),
                _ToolbarAction(
                  tooltip: shareContactTooltip,
                  onPressed: sending ? null : onShareContact,
                  child: ChatIcon(
                    HugeIcons.strokeRoundedContactBook,
                    size: _iconSize,
                    color: muted,
                  ),
                ),
                if (isGroup)
                  _ToolbarAction(
                    tooltip: mentionTooltip,
                    onPressed: sending ? null : onMention,
                    child: Text(
                      '@',
                      style: TextStyle(
                        color: muted,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w600,
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
                    size: _iconSize,
                  ),
                ),
                const Spacer(),
                if (sending)
                  const SizedBox(
                    width: _actionSize,
                    height: _actionSize,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: canSend ? onSend : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, _actionSize),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      foregroundColor: colors.primary,
                      disabledForegroundColor: muted.withValues(alpha: 0.45),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(sendLabel),
                  ),
              ],
            ),
          ),
        ],
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
    visualDensity: VisualDensity.standard,
    constraints: const BoxConstraints.tightFor(
      width: ComposerSlackField._actionSize,
      height: ComposerSlackField._actionSize,
    ),
    padding: EdgeInsets.zero,
    icon: child,
  );
}
