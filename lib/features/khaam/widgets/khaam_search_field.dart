import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';

/// Search input that sits inside [JPackBottomBar]'s capsule.
class JPackSearchField extends StatelessWidget {
  const JPackSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SizedBox(width: 20),
        ChatIcon(
          HugeIcons.strokeRoundedSearch01,
          size: 22,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hintText,
              hintMaxLines: 1,
              hintStyle: TextStyle(
                fontSize: 16,
                color: colors.onSurfaceVariant,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          InkResponse(
            radius: 22,
            onTap: () {
              controller.clear();
              onChanged('');
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ChatIcon(
                HugeIcons.strokeRoundedCancel01,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
