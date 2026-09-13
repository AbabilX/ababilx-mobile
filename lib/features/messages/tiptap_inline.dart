import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tiptap_autolink.dart';

/// Link blue, shared by every surface that renders a body.
const tiptapLinkColor = Color(0xFF64B5F6);

/// Inline half of the TipTap renderer: text nodes, marks, mentions, links.
class TiptapInline {
  TiptapInline({
    required this.context,
    required this.baseStyle,
    required this.onRecognizer,
    this.onMentionTap,
  });

  final BuildContext context;
  final TextStyle baseStyle;

  /// Handed every recognizer built here so the owning widget can dispose them.
  final ValueChanged<TapGestureRecognizer> onRecognizer;

  /// Opens the person a mention names. Absent on surfaces with nobody to open
  /// — the wall and the board draw the same chip and have no profile sheet —
  /// and a chip with no handler is deliberately inert rather than a control
  /// that swallows a tap.
  final void Function(String userId, String label)? onMentionTap;

  List<InlineSpan>? spansOf(dynamic content) {
    if (content is! List || content.isEmpty) return null;
    final spans = <InlineSpan>[];
    for (final raw in content) {
      if (raw is! Map) continue;
      spans.addAll(_spansOfNode(Map<String, dynamic>.from(raw)));
    }
    return spans.isEmpty ? null : spans;
  }

  /// Flattens a node list to text — code blocks keep their source verbatim.
  String plainOf(dynamic content) {
    if (content is! List) return '';
    return content
        .whereType<Map>()
        .map((n) => _nodeToPlain(Map<String, dynamic>.from(n)))
        .join();
  }

  /// URLs, emails and phone numbers in a bubble become tappable. Detection
  /// is [detectAutolinks] so a pasted `017…` or `name@x.com` opens the
  /// dialer / mailer the same way a `https://` link already did.
  List<InlineSpan> linkify(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final hit in detectAutolinks(text)) {
      if (hit.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, hit.start), style: style),
        );
      }
      spans.add(linkSpan(hit.text, hit.href, _linkStyle(style)));
      start = hit.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return spans;
  }

  InlineSpan linkSpan(String text, String href, TextStyle style) {
    final recognizer = TapGestureRecognizer()..onTap = () => _open(href);
    onRecognizer(recognizer);
    return TextSpan(text: text, style: style, recognizer: recognizer);
  }

  TextStyle _linkStyle(TextStyle style) => style.copyWith(
    color: tiptapLinkColor,
    decoration: TextDecoration.underline,
    decorationColor: tiptapLinkColor.withValues(alpha: 0.45),
  );

  List<InlineSpan> _spansOfNode(Map<String, dynamic> node) {
    final type = node['type'];
    if (type == 'hardBreak') return const [TextSpan(text: '\n')];
    if (type == 'mention' || type == 'wallCategory') {
      return [_tagSpan(node, mention: type == 'mention')];
    }
    if (type != 'text') {
      final nested = spansOf(node['content']);
      return nested == null ? const [] : [TextSpan(children: nested)];
    }
    return _textSpans(node);
  }

  /// A mention or a category, drawn as a chip the way the web client draws it.
  ///
  /// It is a [WidgetSpan] rather than a [TextSpan] with a background colour,
  /// for the same reason the web rule carries `whitespace-nowrap`: a display
  /// name contains a space, Flutter's line breaker treats that space as a break
  /// opportunity like any other, and a background painted per line box then
  /// comes out as two ragged halves of one name. A widget is one unbreakable
  /// unit, and it is also the only way to get the padding and the corner radius
  /// that make a chip read as a chip instead of a highlighter swipe. The
  /// conversation-list preview already draws mentions this way, so this keeps
  /// the two surfaces telling the same story.
  InlineSpan _tagSpan(Map<String, dynamic> node, {required bool mention}) {
    final colors = Theme.of(context).colorScheme;
    final tint = mention ? colors.primary : colors.tertiary;
    final attrs = node['attrs'];
    final label = attrs is Map
        ? (attrs['label'] ?? attrs['id'] ?? '').toString()
        : '';
    final userId = attrs is Map ? (attrs['id'] ?? '').toString() : '';
    final onTap = onMentionTap;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${mention ? '@' : '#'}$label',
        style: baseStyle.copyWith(color: tint, fontWeight: FontWeight.w700),
      ),
    );
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: mention && onTap != null && userId.isNotEmpty
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(userId, label),
              child: chip,
            )
          : chip,
    );
  }

  List<InlineSpan> _textSpans(Map<String, dynamic> node) {
    final text = node['text'] as String? ?? '';
    if (text.isEmpty) return const [];

    final colors = Theme.of(context).colorScheme;
    // Decorations accumulate: strikethrough plus a link underline are both
    // possible on one span, and copyWith would keep only the last one.
    final decorations = <TextDecoration>[];
    var style = baseStyle;
    String? href;

    final marks = node['marks'];
    if (marks is List) {
      for (final raw in marks) {
        if (raw is! Map) continue;
        final mark = Map<String, dynamic>.from(raw);
        switch (mark['type']) {
          case 'bold':
            style = style.copyWith(fontWeight: FontWeight.w700);
          case 'italic':
            style = style.copyWith(fontStyle: FontStyle.italic);
          case 'strike':
            decorations.add(TextDecoration.lineThrough);
          case 'underline':
            decorations.add(TextDecoration.underline);
          case 'code':
            style = style.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colors.surfaceContainerHighest,
            );
          case 'link':
            final value = (mark['attrs'] as Map?)?['href']?.toString();
            if (value != null && value.isNotEmpty) href = value;
        }
      }
    }
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }
    if (href != null) return [linkSpan(text, href, _linkStyle(style))];
    return linkify(text, style);
  }

  String _nodeToPlain(Map<String, dynamic> node) {
    final type = node['type'];
    if (type == 'hardBreak') return '\n';
    if (type == 'text') return node['text'] as String? ?? '';
    final inner = node['content'];
    if (inner is! List) return '';
    return inner
        .whereType<Map>()
        .map((n) => _nodeToPlain(Map<String, dynamic>.from(n)))
        .join();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
