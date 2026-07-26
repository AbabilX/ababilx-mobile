import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Focused Slack field row: text + expand toggle.
class ComposerExpandedField extends StatelessWidget {
  const ComposerExpandedField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.tall,
    required this.onToggleTall,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool tall;
  final VoidCallback onToggleTall;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: tall ? 4 : 1,
            maxLines: tall ? 10 : 5,
            style: const TextStyle(fontSize: 16, height: 1.35),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: colors.onSurfaceVariant),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        IconButton(
          tooltip: tall ? 'Collapse' : 'Expand',
          onPressed: onToggleTall,
          icon: ChatIcon(
            tall
                ? HugeIcons.strokeRoundedArrowShrink01
                : HugeIcons.strokeRoundedArrowExpand,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
