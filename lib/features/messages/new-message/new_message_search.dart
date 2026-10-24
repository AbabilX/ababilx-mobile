import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// The one search pill on New message. In [handle] mode the field reads as a
/// username: a grey `@` sits in front of what is typed (it is never part of
/// the text, so the query stays the bare handle), spaces and `@` cannot be
/// typed, and the keyboard offers no suggestions.
class NewMessageSearch extends StatelessWidget {
  const NewMessageSearch({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    this.handle = false,
    this.helper,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool handle;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inputStyle = textTheme.bodyLarge;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, helper == null ? 12 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            onChanged: onChanged,
            style: inputStyle,
            autocorrect: false,
            enableSuggestions: !handle,
            textInputAction: TextInputAction.search,
            inputFormatters: handle
                ? [FilteringTextInputFormatter.deny(RegExp(r'[\s@]'))]
                : null,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                0,
                14,
                8,
                14,
              ),
              prefixIcon: handle
                  ? _AtSign(style: inputStyle, color: colors.onSurfaceVariant)
                  : Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 16,
                        end: 10,
                      ),
                      child: ChatIcon(
                        HugeIcons.strokeRoundedSearch01,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
              prefixIconConstraints: const BoxConstraints(),
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
                      icon: ChatIcon(
                        HugeIcons.strokeRoundedCancel01,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
              border: pill,
              enabledBorder: pill,
              focusedBorder: pill,
            ),
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 4),
              child: Text(
                helper!,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Same size as the typed text so `@` and the handle read as one word.
class _AtSign extends StatelessWidget {
  const _AtSign({required this.style, required this.color});

  final TextStyle? style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 20, end: 1),
      child: Text(
        '@',
        style: style?.copyWith(
          color: color.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
