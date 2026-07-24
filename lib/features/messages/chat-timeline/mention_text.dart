import 'package:flutter/material.dart';

/// Renders @mentions + http(s) links like Slack.
class MentionText extends StatelessWidget {
  const MentionText({super.key, required this.text, this.edited = false});

  final String text;
  final bool edited;

  static final _tokenRe = RegExp(
    r'(@[\w.\- ]+|https?:\/\/[^\s<>\[\]()]+)',
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final linkColor = const Color(0xFF64B5F6);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in _tokenRe.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      final token = m.group(0)!;
      if (token.startsWith('@')) {
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withValues(alpha: 0.45),
          ),
        ));
      }
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    if (edited) {
      spans.add(TextSpan(
        text: ' (edited)',
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 15,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}
