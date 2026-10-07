import 'package:flutter/material.dart';

import 'snippet_format.dart';
import 'snippet_strings.dart';

InputDecoration _decoration(
  BuildContext context, {
  String? label,
  String? hint,
}) {
  final colors = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: true,
    contentPadding: const EdgeInsets.all(12),
    border: border(colors.outlineVariant),
    enabledBorder: border(colors.outlineVariant),
    focusedBorder: border(colors.primary),
  );
}

class SnippetTitleField extends StatelessWidget {
  const SnippetTitleField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    maxLines: 1,
    maxLength: 80,
    textInputAction: TextInputAction.next,
    decoration: _decoration(
      context,
      label: label,
      hint: hint,
    ).copyWith(counterText: ''),
  );
}

/// Markdown or plain text, as two chips side by side.
class SnippetKindPicker extends StatelessWidget {
  const SnippetKindPicker({
    super.key,
    required this.kind,
    required this.strings,
    required this.onChanged,
  });

  final SnippetKind kind;
  final SnippetStrings strings;
  final ValueChanged<SnippetKind>? onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<SnippetKind>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(
        value: SnippetKind.markdown,
        label: Text(strings.markdown, maxLines: 1),
      ),
      ButtonSegment(
        value: SnippetKind.text,
        label: Text(strings.plainText, maxLines: 1),
      ),
    ],
    selected: {kind},
    onSelectionChanged: onChanged == null
        ? null
        : (picked) => onChanged!(picked.first),
  );
}

/// The content box: fills the page, monospace, no autocorrect — it holds logs
/// and code as often as prose.
class SnippetContentField extends StatelessWidget {
  const SnippetContentField({
    super.key,
    required this.controller,
    required this.hint,
    required this.enabled,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    expands: true,
    maxLines: null,
    minLines: null,
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.multiline,
    textAlignVertical: TextAlignVertical.top,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', height: 1.4),
    decoration: _decoration(context, hint: hint),
  );
}

class SnippetMessageField extends StatelessWidget {
  const SnippetMessageField({
    super.key,
    required this.controller,
    required this.hint,
    required this.enabled,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    minLines: 1,
    maxLines: 3,
    keyboardType: TextInputType.multiline,
    textCapitalization: TextCapitalization.sentences,
    decoration: _decoration(context, hint: hint),
  );
}
