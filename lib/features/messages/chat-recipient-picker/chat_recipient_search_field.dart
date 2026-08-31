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
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 12),
      child: TextField(
        controller: controller,
        autofocus: false,
        enabled: enabled,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: colors.surfaceContainerHighest,
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
            borderRadius: BorderRadius.circular(34),
            borderSide: BorderSide.none,
          ),
        ),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
