import 'package:flutter/material.dart';

import '../../messages/chat-timeline/composer_expanded_field.dart';
import '../../messages/chat-timeline/composer_soon.dart';
import '../../messages/chat-timeline/composer_text_actions.dart';
import '../../messages/chat-timeline/composer_toolbar.dart';
import 'reply_banner.dart';

class WallCommentExpanded extends StatelessWidget {
  const WallCommentExpanded({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.tall,
    required this.busy,
    required this.canSend,
    required this.replyLabel,
    required this.onClearReply,
    required this.onToggleTall,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool tall;
  final bool busy;
  final bool canSend;
  final String? replyLabel;
  final VoidCallback? onClearReply;
  final VoidCallback onToggleTall;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyLabel != null)
                WallReplyBanner(label: replyLabel!, onClear: onClearReply),
              ComposerExpandedField(
                controller: controller,
                focusNode: focusNode,
                hint: hint,
                tall: tall,
                onToggleTall: onToggleTall,
                onSubmitted: onSend,
              ),
              ComposerToolbar(
                sending: busy,
                canSend: canSend,
                onShortcuts: () => showComposerSoon(context, 'Shortcuts'),
                onEmoji: () => showEmojiPicker(
                  context,
                  (e) => insertComposerEmoji(controller, e),
                ),
                onMention: () => insertComposerAt(controller),
                onFormat: () => wrapComposerBold(controller),
                onAttachFile: () => showComposerSoon(context, 'Attachments'),
                onAttachImage: () => showComposerSoon(context, 'Attachments'),
                onSend: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
