import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders @mentions + tappable http(s) links like Slack.
class MentionText extends StatefulWidget {
  const MentionText({super.key, required this.text, this.edited = false});

  final String text;
  final bool edited;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  static final _tokenRe = RegExp(r'(@[\w.\- ]+|https?:\/\/[^\s<>\[\]()]+)');

  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _linkRecognizer(String url) {
    final r = TapGestureRecognizer()
      ..onTap = () {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild recognizers when text changes.
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final colors = Theme.of(context).colorScheme;
    const linkColor = Color(0xFF64B5F6);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in _tokenRe.allMatches(widget.text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: widget.text.substring(start, m.start)));
      }
      final token = m.group(0)!;
      if (token.startsWith('@')) {
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        var url = token;
        final suffix = RegExp(r'[.,;!?)]+$').firstMatch(url);
        if (suffix != null) {
          url = url.substring(0, url.length - suffix.group(0)!.length);
        }
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor.withValues(alpha: 0.45),
            ),
            recognizer: _linkRecognizer(url),
          ),
        );
      }
      start = m.end;
    }
    if (start < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(start)));
    }
    if (widget.edited) {
      spans.add(
        TextSpan(
          text: ' (edited)',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      );
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(color: colors.onSurface, fontSize: 15, height: 1.4),
        children: spans,
      ),
    );
  }
}
