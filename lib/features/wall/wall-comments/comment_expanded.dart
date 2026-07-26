import 'package:flutter/material.dart';

import '../../../shared/widgets/action_composer.dart';
import '../data/models/wall_models.dart';
import '../wall-composer/pending_previews.dart';
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
    required this.pending,
    required this.onRemovePending,
    required this.onAddPhoto,
    required this.actions,
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
  final List<WallAttachmentInput> pending;
  final ValueChanged<int> onRemovePending;
  final VoidCallback onAddPhoto;
  final List<Widget> actions;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ActionComposer(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      busy: busy,
      canSend: canSend,
      showHandle: true,
      minLines: tall ? 5 : 1,
      maxLines: tall ? 10 : 6,
      header: replyLabel == null
          ? null
          : WallReplyBanner(label: replyLabel!, onClear: onClearReply),
      pending: pending.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: WallPendingPreviews(
                items: pending,
                onRemove: onRemovePending,
                onAddPhoto: onAddPhoto,
              ),
            ),
      actions: actions,
      onSend: onSend,
    );
  }
}
