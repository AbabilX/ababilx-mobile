import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/khaam_payload.dart';

/// The message box: a plain filled capsule, no border, no shadow.
class KhaamSettingRow extends StatelessWidget {
  const KhaamSettingRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }
}

/// The message box on the compose screen: [khaamCaptionMaxChars] characters,
/// two lines, with how many are left shown at the end.
class KhaamMessageField extends StatelessWidget {
  const KhaamMessageField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KhaamSettingRow(
      child: TextField(
        controller: controller,
        // Hard cap: the caption is written on the envelope's flap, which has
        // room for two short lines and no more.
        maxLength: khaamCaptionMaxChars,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        minLines: 1,
        maxLines: 2,
        onChanged: onChanged,
        style: theme.textTheme.titleMedium,
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final left = khaamCaptionMaxChars - value.text.characters.length;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '$left',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: left <= 5
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 28),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
        ),
      ),
    );
  }
}
