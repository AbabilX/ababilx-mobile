import 'package:flutter/material.dart';

class ContactSearchField extends StatelessWidget {
  const ContactSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.placeholder,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: placeholder,
        prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
