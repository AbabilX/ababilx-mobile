import 'package:flutter/material.dart';

/// The "Add a message" capsule a share shows above the keyboard once a
/// destination is picked. Send itself lives in the header.
class ChatRecipientCaptionBar extends StatelessWidget {
  const ChatRecipientCaptionBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.enabled,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: controller,
          enabled: enabled,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
          ),
        ),
      ),
    );
  }
}
