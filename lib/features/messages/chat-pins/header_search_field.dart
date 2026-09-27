import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// A quiet pill: filled, no outline, small icon — the theme's input style
/// (outlined, 48dp icon box) is for forms, not a list filter.
class HeaderSearchField extends StatelessWidget {
  const HeaderSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const none = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(22)),
      borderSide: BorderSide.none,
    );
    // letterSpacing 0: typed Bangla shapes like everywhere else.
    const text = TextStyle(fontSize: 15, letterSpacing: 0);
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: text,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          // The header capsules' frosted fill, so it reads as one of them.
          fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.94),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          hintText: hint,
          hintStyle: text.copyWith(color: colors.onSurfaceVariant),
          prefixIcon: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: ChatIcon(
                HugeIcons.strokeRoundedSearch01,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(),
          border: none,
          enabledBorder: none,
          focusedBorder: none,
        ),
      ),
    );
  }
}
