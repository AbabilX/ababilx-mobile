import 'package:flutter/material.dart';

class ChatRecipientSearchField extends StatelessWidget {
  const ChatRecipientSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        autofocus: false,
        enabled: enabled,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}
