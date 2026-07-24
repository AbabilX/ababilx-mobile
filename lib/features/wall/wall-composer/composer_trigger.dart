import 'package:flutter/material.dart';

/// Detects an active `@mention` or `#category` trigger before the cursor.
class ComposerTrigger {
  const ComposerTrigger({
    required this.isMention,
    required this.start,
    required this.query,
  });

  final bool isMention;
  final int start; // index of @ or #
  final String query;

  int get end => start + 1 + query.length;
}

ComposerTrigger? detectComposerTrigger(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final before = text.substring(0, cursor);

  final at = RegExp(r'(?:^|[\s\n])(@)([^\s@#]*)$').firstMatch(before);
  if (at != null) {
    final atIdx = before.lastIndexOf('@');
    return ComposerTrigger(
      isMention: true,
      start: atIdx,
      query: at.group(2) ?? '',
    );
  }

  // Categories may include spaces (web allowSpaces).
  final hash = RegExp(r'(?:^|[\s\n])(#)([^\n@]*)$').firstMatch(before);
  if (hash != null) {
    final hashIdx = before.lastIndexOf('#');
    return ComposerTrigger(
      isMention: false,
      start: hashIdx,
      query: hash.group(2) ?? '',
    );
  }
  return null;
}

/// Replace `@query` / `#query` with the chosen label + trailing space.
void applyComposerTrigger(
  TextEditingController ctrl,
  ComposerTrigger trigger,
  String label,
) {
  final t = ctrl.text;
  final insert = '${trigger.isMention ? '@' : '#'}$label ';
  final next = t.replaceRange(trigger.start, trigger.end.clamp(0, t.length), insert);
  ctrl.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: trigger.start + insert.length),
  );
}
